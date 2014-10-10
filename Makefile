all:
		mix compile
clean:     
		mix clean
		mix deps.clean --all
		mix deps.get
reload: clean all
hard_reload: 
		rm -rf ./mix.lock
		mix clean
		mix deps.clean --all
		mix deps.get
		mix compile