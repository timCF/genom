web_interface = angular.module "web_interface", ["ngSanitize"] 
controllers = {}


controllers.my_controller = ($scope, $http, $interval, $sanitize) ->
	$scope.init_const = () ->
		$scope.const = {}
		$scope.const.colors = {}
		$scope.const.colors.host_alive = '#66FFCC'
		$scope.const.colors.host_dead = '#FFCCCC'
		$scope.const.colors.app_alive = '#33FF00'
		$scope.const.colors.app_dead = '#FF0000'
	$scope.generate_host_style = (status) ->
		if status == "alive"
			{'background-color':$scope.const.colors.host_alive}
		else
			{'background-color':$scope.const.colors.host_dead}
	$scope.generate_app_style = (status) ->
		if status == "alive"
			{'background-color':$scope.const.colors.app_alive}
		else
			{'background-color':$scope.const.colors.app_dead}
	$scope.init = () ->
		$scope.init_const()
		$scope.bullet = $.bullet("ws://" + location.host + "/bullet")
		$scope.bullet.onopen = () ->
			console.log("bullet: connected")
			mess = {"subject": "get_state","content": "nil"}
			$scope.bullet.send(JSON.stringify(mess))
		$scope.bullet.ondisconnect = () ->
			console.log("bullet: disconnected")
		$scope.bullet.onclose = () ->
			console.log("bullet: closed")
		$scope.bullet.onmessage = (e) ->
			mess = $.parseJSON(e.data)
			if mess.subject == "error" 
				alert mess.content
			if mess.subject == "pong"
				"ok"
			if mess.subject == "refresh"
				$scope.state = mess.content
		$scope.bullet.onheartbeat = () ->
			mess = {"subject": "ping","content": "nil"}
			$scope.bullet.send(JSON.stringify(mess))
		# next , define functions for UI
		$interval( (->) , 500, [], [])
web_interface.controller(controllers)