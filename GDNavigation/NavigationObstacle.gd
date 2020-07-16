tool
extends Spatial
class_name NavObstacle

export var size : float = 1.0
export var is_child : bool
export var show_sphere : bool
onready var FCircle = ImmediateGeometry.new()
var verts : float
var agents : Array = []
var scan : bool
var pos : Vector3

func _ready():
	self.add_child(FCircle)
	scan = true

func scan_agents():
	while true:
		agents.clear()
		for i in get_tree().get_current_scene().get_children():
			if i is NavAgent && i != get_parent() && i.active:
				agents.append(i)
			else:
				for c in i.get_children():
					if c is NavAgent && c != get_parent() && c.active:
						agents.append(c)
		yield(get_tree(),"idle_frame")

func _physics_process(delta):
	if !Engine.editor_hint:
		pos = translation
		if is_child:
			pos += get_parent().get_translation()
		
		if show_sphere:
			show_sphere = false
			FCircle.begin(Mesh.PRIMITIVE_LINES, null)
			verts = size*4
			verts = clamp(verts, 6, 30)
			FCircle.add_sphere(verts, verts, size, true)
			FCircle.end()
		if scan:
			yield(get_tree(),"idle_frame")
			yield(get_tree(),"idle_frame")
			scan = false
			scan_agents()
			yield(get_tree(),"idle_frame")
		else:
			for i in agents.size():
				var change = false
				if is_child && pos.distance_to(agents[i].translation) < size:
					agents[i].avoid_speed += delta*agents[i].avoidance*3
				for point in agents[i].pathway.size():
					if pos.distance_to(agents[i].pathway[point]) < size && agents[i].pathway.size() > point:
						change = true
						var move_dir = pos - agents[i].pathway[point]
						move_dir.y = 0
						while pos.distance_to(agents[i].pathway[point]) < size:
							agents[i].pathway[point] -= move_dir.normalized()
						var wallhit = get_world().direct_space_state.intersect_ray(pos, agents[i].pathway[point], agents)
						if wallhit:
							move_dir = pos - agents[i].pathway[point]
							move_dir.y = lerp(agents[i].pathway[point-1].y, agents[i].pathway[point+1].y, 0.5)
							agents[i].pathway[point] = pos + move_dir
					else:
						change = false
				if change:
					manipulation(agents[i])
	else:
		if !scan:
			scan = true
		size = clamp(size, 0.1, 100)
		FCircle.clear()
		FCircle.begin(Mesh.PRIMITIVE_LINES, null)
		verts = size*4
		verts = clamp(verts, 6, 30)
		FCircle.add_sphere(verts, verts, size, true)
		FCircle.end()

func manipulation(agent):
	var done
	done = false
	var closest_dist = pos.distance_to(agents[0].pathway[0])
	var closest_point = 0
	for point in agent.pathway.size():
		if pos.distance_to(agent.pathway[point]) < closest_dist:
			closest_point = point
	closest_point = clamp(closest_point, 1, agent.pathway.size()-2)
	var lerp_vec = 0.0
	var additional_point
	var move
	while agent.active && lerp_vec < 1.0 && agent.pathway.size() > closest_point:
		if !done && pos.distance_to(lerp(agent.pathway[closest_point-1], agent.pathway[closest_point], lerp_vec)) < size+2:
			additional_point = lerp(agent.pathway[closest_point-1], agent.pathway[closest_point], lerp_vec+0.2)
			move = pos - additional_point
			move = Vector3(-move.x, move.y*0.05, -move.z)
			additional_point = pos + move.normalized()*size
			agent.pathway[closest_point-1] = additional_point
			var wallhit = get_world().direct_space_state.intersect_ray(pos, agent.pathway[closest_point-1], agents)
			if wallhit:
				var move_dir = pos - agent.pathway[closest_point-1]
				move_dir.y = lerp(agent.pathway[closest_point-2].y, agent.pathway[closest_point].y, 0.5)
				agent.pathway[closest_point-1] = pos + move_dir
			done = true
		elif !done && pos.distance_to(lerp(agent.pathway[closest_point], agent.pathway[closest_point+1], lerp_vec)) < size+2:
			additional_point = lerp(agent.pathway[closest_point], agent.pathway[closest_point+1], lerp_vec+0.2)
			move = pos - additional_point
			move = Vector3(-move.x, move.y*0.05, -move.z)
			additional_point = pos + move.normalized()*size
			agent.pathway[closest_point] = additional_point
			var wallhit = get_world().direct_space_state.intersect_ray(pos, agent.pathway[closest_point], agents)
			if wallhit:
				var move_dir = pos - agent.pathway[closest_point]
				move_dir.y = lerp(agent.pathway[closest_point-1].y, agent.pathway[closest_point+1].y, 0.5)
				agent.pathway[closest_point] = pos + move_dir
			done = true
		lerp_vec += 0.1
		yield(get_tree(),"idle_frame")
