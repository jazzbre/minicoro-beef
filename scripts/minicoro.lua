project "minicoro"
	kind "StaticLib"
	windowstargetplatformversion("10.0")

	defines {
      MCO_API
	}

	includedirs {
      path.join(SOURCE_DIR, "minicoro"),
   }
      
	files {
		
		path.join(SOURCE_DIR, "../csrc/minicoro.cc"),
	}

	configuration {}	
