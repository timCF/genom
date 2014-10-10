all:
		mix compile
clean:     
		mix clean
		mix deps.clean --all
		mix deps.get
reload: clean all