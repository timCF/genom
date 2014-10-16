all:
		git pull
		mix clean
		mix deps.clean --all
		mix deps.get
		docker build --rm -t pfya/genom .
push:
		docker push pfya/genom