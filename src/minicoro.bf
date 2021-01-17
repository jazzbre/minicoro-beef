using System;

namespace minicoro
{
	class Coroutine
	{
		public typealias Callback = delegate void();

		private mco_desc desc;
		private mco_coro* co;

		public bool IsValid => co != null;
		public bool IsRunning => IsValid && mco_status(co) != .MCO_DEAD;

		public Callback Callback { get; private set; }

		public this(Callback callback, uint stackSize = 0xffff)
		{
			Callback = callback;
			desc = mco_desc_init( => Main, stackSize);
			desc.user_data = Internal.UnsafeCastToPtr(this);
			var res = mco_create(&co, &desc);
			if (res != .MCO_SUCCESS)
			{
				return;
			}
		}

		public ~this()
		{
			mco_destroy(co);
			co = null;
		}

		public void Resume()
		{
			if (!IsValid)
			{
				return;
			}
			mco_resume(co);
		}

		public static void Yield()
		{
			mco_yield(mco_running());
		}

		private static void Main(mco_coro* co)
		{
			var coroutine = Internal.UnsafeCastToObject(mco_get_user_data(co)) as Coroutine;
			coroutine.Callback();
		}

		/* Coroutine states. */
		private enum mco_state : int32
		{
			MCO_DEAD = 0,/* The coroutine has finished normally or was uninitialized before finishing. */
			MCO_NORMAL,/* The coroutine is active but not running (that is, it has resumed another coroutine). */
			MCO_RUNNING,/* The coroutine is active and running. */
			MCO_SUSPENDED,/* The coroutine is suspended (in a call to yield, or it has not started running yet). */
		};

		  /* Coroutine result codes. */
		private enum mco_result : int32
		{
			MCO_SUCCESS = 0,
			MCO_GENERIC_ERROR,
			MCO_INVALID_POINTER,
			MCO_INVALID_COROUTINE,
			MCO_NOT_SUSPENDED,
			MCO_NOT_RUNNING,
			MCO_MAKE_CONTEXT_ERROR,
			MCO_SWITCH_CONTEXT_ERROR,
			MCO_NOT_ENOUGH_SPACE,
			MCO_OUT_OF_MEMORY,
			MCO_INVALID_ARGUMENTS,
			MCO_INVALID_OPERATION,
		};

		/// Callback type for a function that draws a filled, stroked circle.
		private typealias mco_coro_func = function void(mco_coro* co);
		private typealias mco_coro_malloc_cb = function void*(uint size, void* allocator_data);
		private typealias mco_coro_free_cb = function void(void* ptr, void* allocator_data);

		  /* Coroutine structure. */
		[CRepr]
		private struct mco_coro
		{
			public void* context;
			public mco_state state;
			public mco_coro_func func;
			public mco_coro* prev_co;
			public void* user_data;
			public void* allocator_data;
			public mco_coro_free_cb free_cb;
			public void* stack_base;/* Stack base address, can be used to scan memory in a garbage collector. */
			public uint stack_size;
			public uint8* storage;
			public uint bytes_stored;
			public uint storage_size;
			public void* asan_prev_stack;/* Used by address sanitizer. */
			public void* tsan_prev_fiber;/* Used by thread sanitizer. */
			public void* tsan_fiber;/* Used by thread sanitizer. */
		};

		  /* Structure used to initialize a coroutine. */
		[CRepr]
		private struct mco_desc
		{
			public mco_coro_func func;/* Entry point function for the coroutine. */
			public void* user_data;/* Coroutine user data, can be get with `mco_get_user_data`. */
			/* Custom allocation interface. */
			public mco_coro_malloc_cb malloc_cb;/* Custom allocation function. */
			public mco_coro_free_cb free_cb;/* Custom deallocation function. */
			public void* allocator_data;/* User data pointer passed to `malloc`/`free` allocation functions. */
			public uint storage_size;/* Coroutine storage size, to be used with the storage APIs. */
			/* These must be initialized only through `mco_init_desc`. */
			public uint coro_size;/* Coroutine structure size. */
			public uint stack_size;/* Coroutine stack size. */
		};

		/* Coroutine functions. */
		[CLink] private static extern mco_desc mco_desc_init(mco_coro_func func, uint stack_size);/* Initialize
		description of a coroutine. When stack size is 0 then MCO_DEFAULT_STACK_SIZE is be used. */
		[CLink] private static extern mco_result mco_init(mco_coro* co, mco_desc* desc);/* Initialize the coroutine. */
		[CLink] private static extern mco_result mco_uninit(mco_coro* co);/* Uninitialize the coroutine, may fail if
		it's not dead or suspended. */
		[CLink] private static extern mco_result mco_create(mco_coro** out_co, mco_desc* desc);/* Allocates and
		initializes a new coroutine. */
		[CLink] private static extern mco_result mco_destroy(mco_coro* co);/* Uninitialize and deallocate the coroutine,
		may fail if it's not dead or suspended. */
		[CLink] private static extern mco_result mco_resume(mco_coro* co);/* Starts or continues the execution of the
		coroutine. */
		[CLink] private static extern mco_result mco_yield(mco_coro* co);/* Suspends the execution of a coroutine. */
		[CLink] private static extern mco_state mco_status(mco_coro* co);/* Returns the status of the coroutine. */
		[CLink] private static extern void* mco_get_user_data(mco_coro* co);/* Get coroutine user data supplied on
		coroutine creation. */

		/* Storage interface functions, used to pass values between yield and resume. */
		[CLink] private static extern mco_result mco_push(mco_coro* co, void* src, uint len);/* Push bytes to the
		coroutine storage. Use to send values between yield and resume. */
		[CLink] private static extern mco_result mco_pop(mco_coro* co, void* dest, uint len);/* Pop bytes from the
		coroutine storage. Use to get values between yield and resume. */
		[CLink] private static extern mco_result mco_peek(mco_coro* co, void* dest, uint len);/* Like `mco_pop` but it
		does not consumes the storage. */
		[CLink] private static extern uint mco_get_bytes_stored(mco_coro* co);/* Get the available bytes that can be
		retrieved with a `mco_pop`. */
		[CLink] private static extern uint mco_get_storage_size(mco_coro* co);/* Get the total storage size. */

		/* Misc functions. */
		[CLink] private static extern mco_coro* mco_running();/* Returns the running coroutine for the current
		thread. */
		[CLink] private static extern char8* mco_result_description(mco_result res);/* Get the description of a result.
	*/

	}
}
