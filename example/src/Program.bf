using System;
using minicoro;

namespace example
{
	class Program
	{
		static int Main()
		{
			var coroutine = scope Coroutine(scope [&] () =>
				{
					Console.WriteLine("coroutine 1");
					Coroutine.Yield();
					Console.WriteLine("coroutine 2");
				});
			int frameIndex = 0;
			while (coroutine.IsRunning)
			{
				Console.WriteLine(scope $"Frame Index {++frameIndex}");
				coroutine.Resume();
			}
			return 0;
		}
	}
}
