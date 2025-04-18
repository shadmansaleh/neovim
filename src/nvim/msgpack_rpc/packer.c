#include <assert.h>
#include <lauxlib.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/memory.h"
#include "nvim/msgpack_rpc/packer.h"
#include "nvim/types_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/packer.c.generated.h"
#endif

void mpack_check_buffer(PackerBuffer *packer)
{
  if (mpack_remaining(packer) < 2 * MPACK_ITEM_SIZE) {
    packer->packer_flush(packer);
  }
}

static void mpack_w8(char **b, const char *data)
{
#ifdef ORDER_BIG_ENDIAN
  memcpy(*b, data, 8);
  *b += 8;
#else
  for (int i = 7; i >= 0; i--) {
    *(*b)++ = data[i];
  }
#endif
}

void mpack_uint64(char **ptr, uint64_t i)
{
  if (i > 0xfffffff) {
    mpack_w(ptr, 0xcf);
    mpack_w8(ptr, (char *)&i);
  } else {
    mpack_uint(ptr, (uint32_t)i);
  }
}

void mpack_integer(char **ptr, Integer i)
{
  if (i >= 0) {
    mpack_uint64(ptr, (uint64_t)i);
  } else {
    if (i < -0x80000000LL) {
      mpack_w(ptr, 0xd3);
      mpack_w8(ptr, (char *)&i);
    } else if (i < -0x8000) {
      mpack_w(ptr, 0xd2);
      mpack_w4(ptr, (uint32_t)i);
    } else if (i < -0x80) {
      mpack_w(ptr, 0xd1);
      mpack_w2(ptr, (uint32_t)i);
    } else if (i < -0x20) {
      mpack_w(ptr, 0xd0);
      mpack_w(ptr, (char)i);
    } else {
      mpack_w(ptr, (char)i);
    }
  }
}

void mpack_float8(char **ptr, double i)
{
  mpack_w(ptr, 0xcb);
  mpack_w8(ptr, (char *)&i);
}

void mpack_str(String str, PackerBuffer *packer)
{
  const size_t len = str.size;
  if (len < 20) {
    mpack_w(&packer->ptr, 0xa0 | len);
  } else if (len < 0xff) {
    mpack_w(&packer->ptr, 0xd9);
    mpack_w(&packer->ptr, len);
  } else if (len < 0xffff) {
    mpack_w(&packer->ptr, 0xda);
    mpack_w2(&packer->ptr, (uint32_t)len);
  } else if (len < 0xffffffff) {
    mpack_w(&packer->ptr, 0xdb);
    mpack_w4(&packer->ptr, (uint32_t)len);
  } else {
    abort();
  }

  mpack_raw(str.data, len, packer);
}

void mpack_bin(String str, PackerBuffer *packer)
{
  const size_t len = str.size;
  if (len < 0xff) {
    mpack_w(&packer->ptr, 0xc4);
    mpack_w(&packer->ptr, len);
  } else if (len < 0xffff) {
    mpack_w(&packer->ptr, 0xc5);
    mpack_w2(&packer->ptr, (uint32_t)len);
  } else if (len < 0xffffffff) {
    mpack_w(&packer->ptr, 0xc6);
    mpack_w4(&packer->ptr, (uint32_t)len);
  } else {
    abort();
  }

  mpack_raw(str.data, len, packer);
}

void mpack_raw(const char *data, size_t len, PackerBuffer *packer)
{
  size_t pos = 0;
  while (pos < len) {
    ptrdiff_t remaining = packer->endptr - packer->ptr;
    size_t to_copy = MIN(len - pos, (size_t)remaining);
    memcpy(packer->ptr, data + pos, to_copy);
    packer->ptr += to_copy;
    pos += to_copy;

    if (pos < len) {
      packer->packer_flush(packer);
    }
  }
  mpack_check_buffer(packer);
}

void mpack_ext(char *buf, size_t len, int8_t type, PackerBuffer *packer)
{
  if (len == 1) {
    mpack_w(&packer->ptr, 0xd4);
  } else if (len == 2) {
    mpack_w(&packer->ptr, 0xd5);
  } else if (len <= 0xff) {
    mpack_w(&packer->ptr, 0xc7);
  } else if (len < 0xffff) {
    mpack_w(&packer->ptr, 0xc8);
    mpack_w2(&packer->ptr, (uint32_t)len);
  } else if (len < 0xffffffff) {
    mpack_w(&packer->ptr, 0xc9);
    mpack_w4(&packer->ptr, (uint32_t)len);
  } else {
    abort();
  }
  mpack_w(&packer->ptr, type);
  mpack_raw(buf, len, packer);
}

void mpack_handle(ObjectType type, handle_T handle, PackerBuffer *packer)
{
  char exttype = (char)(type - EXT_OBJECT_TYPE_SHIFT);
  if (-0x1f <= handle && handle <= 0x7f) {
    mpack_w(&packer->ptr, 0xd4);
    mpack_w(&packer->ptr, exttype);
    mpack_w(&packer->ptr, (char)handle);
  } else {
    // we want to encode some small negative sentinel like -1. This is handled above
    assert(handle >= 0);
    // FAIL: we cannot use fixext 4/8 due to a design error
    // (in theory fixext 2 for handle<=0xff but we don't gain much from it)
    char buf[MPACK_ITEM_SIZE];
    char *pos = buf;
    mpack_uint(&pos, (uint32_t)handle);
    ptrdiff_t packsize = pos - buf;
    mpack_w(&packer->ptr, 0xc7);
    mpack_w(&packer->ptr, packsize);
    mpack_w(&packer->ptr, exttype);
    memcpy(packer->ptr, buf, (size_t)packsize);
    packer->ptr += packsize;
  }
}

void mpack_object(Object *obj, PackerBuffer *packer)
{
  mpack_object_inner(obj, NULL, 0, packer);
}

void mpack_object_array(Array arr, PackerBuffer *packer)
{
  mpack_array(&packer->ptr, (uint32_t)arr.size);
  if (arr.size > 0) {
    Object container = ARRAY_OBJ(arr);
    mpack_object_inner(&arr.items[0], arr.size > 1 ? &container : NULL, 1, packer);
  }
}

typedef struct {
  Object *container;
  size_t idx;
} ContainerStackItem;

void mpack_object_inner(Object *current, Object *container, size_t container_idx,
                        PackerBuffer *packer)
  FUNC_ATTR_NONNULL_ARG(1, 4)
{
  // The inner loop of this function packs "current" and then fetches the next
  // value from "container". "stack" is only used for nested containers.
  kvec_withinit_t(ContainerStackItem, 2) stack = KV_INITIAL_VALUE;
  kvi_init(stack);

  while (true) {
    mpack_check_buffer(packer);
    switch (current->type) {
    case kObjectTypeLuaRef:
      // TODO(bfredl): could also be an error. Though kObjectTypeLuaRef
      // should only appear when the caller has opted in to handle references,
      // see nlua_pop_Object.
      api_free_luaref(current->data.luaref);
      current->data.luaref = LUA_NOREF;
      FALLTHROUGH;
    case kObjectTypeNil:
      mpack_nil(&packer->ptr);
      break;
    case kObjectTypeBoolean:
      mpack_bool(&packer->ptr, current->data.boolean);
      break;
    case kObjectTypeInteger:
      mpack_integer(&packer->ptr, current->data.integer);
      break;
    case kObjectTypeFloat:
      mpack_float8(&packer->ptr, current->data.floating);
      break;
    case kObjectTypeString:
      mpack_str(current->data.string, packer);
      break;
    case kObjectTypeBuffer:
    case kObjectTypeWindow:
    case kObjectTypeTabpage:
      mpack_handle(current->type, (handle_T)current->data.integer, packer);
      break;
    case kObjectTypeDict:
    case kObjectTypeArray: {}
      size_t current_size;
      if (current->type == kObjectTypeArray) {
        current_size = current->data.array.size;
        mpack_array(&packer->ptr, (uint32_t)current_size);
      } else {
        current_size = current->data.dict.size;
        mpack_map(&packer->ptr, (uint32_t)current_size);
      }
      if (current_size > 0) {
        if (current->type == kObjectTypeArray && current_size == 1) {
          current = &current->data.array.items[0];
          continue;
        }
        if (container) {
          kvi_push(stack, ((ContainerStackItem) {
            .container = container,
            .idx = container_idx,
          }));
        }
        container = current;
        container_idx = 0;
      }
      break;
    }

    if (!container) {
      if (kv_size(stack)) {
        ContainerStackItem it = kv_pop(stack);
        container = it.container;
        container_idx = it.idx;
      } else {
        break;
      }
    }

    if (container->type == kObjectTypeArray) {
      Array arr = container->data.array;
      current = &arr.items[container_idx++];
      if (container_idx >= arr.size) {
        container = NULL;
      }
    } else {
      Dict dict = container->data.dict;
      KeyValuePair *it = &dict.items[container_idx++];
      mpack_check_buffer(packer);
      mpack_str(it->key, packer);
      current = &it->value;
      if (container_idx >= dict.size) {
        container = NULL;
      }
    }
  }
  kvi_destroy(stack);
}

PackerBuffer packer_string_buffer(void)
{
  const size_t initial_size = 64;  // must be larger than SHADA_MPACK_FREE_SPACE
  char *alloc = xmalloc(initial_size);
  return (PackerBuffer) {
    .startptr = alloc,
    .ptr = alloc,
    .endptr = alloc + initial_size,
    .packer_flush = flush_string_buffer,
  };
}

static void flush_string_buffer(PackerBuffer *buffer)
{
  size_t current_capacity = (size_t)(buffer->endptr - buffer->startptr);
  size_t new_capacity = 2 * current_capacity;
  size_t len = (size_t)(buffer->ptr - buffer->startptr);

  buffer->startptr = xrealloc(buffer->startptr, new_capacity);
  buffer->ptr = buffer->startptr + len;
  buffer->endptr = buffer->startptr + new_capacity;
}

/// can only be used with a PackerBuffer from `packer_string_buffer`
String packer_take_string(PackerBuffer *buffer)
{
  return (String){ .data = buffer->startptr, .size = (size_t)(buffer->ptr - buffer->startptr) };
}
