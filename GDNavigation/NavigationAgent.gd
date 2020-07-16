tool
extends KinematicBody
class_name NavAgent

var active = true
export var create_core_nodes : bool
export var navigation_node : NodePath
export var destination : NodePath
export var speed : float
export var acceleration : float
export var turn : float
export var slide : float
export var slide_kill : float
export var gravity : float
export var avoidance : float
export var show_agent_arrow : bool
export var draw_path : bool
var cur_speed : float
var wanted_speed : float
var cur_turn : float
var cur_gravity : Vector3
var avoid_speed : float
var pathway
var original_pathway
var path_point : int
var look_to : float
onready var slider = Spatial.new()
onready var look_towards = Spatial.new()
onready var FLine = ImmediateGeometry.new()
onready var path = ImmediateGeometry.new()
var print_arrow : bool

func _ready():
	self.add_child(FLine)
	show_arrow()
	while true:
		yield(get_tree().create_timer(0.2),"timeout")
		pathway = original_pathway

func show_arrow():
	FLine.begin(Mesh.PRIMITIVE_LINE_STRIP, null)
	FLine.add_vertex(Vector3.ZERO)
	FLine.add_vertex(Vector3(0,0,-2))
	FLine.add_vertex(Vector3(0.25,0,-1.5))
	FLine.add_vertex(Vector3(-0.25,0,-1.5))
	FLine.add_vertex(Vector3(0,0,-2))
	FLine.end()

func Set_Destination(dest):
	active = false
	var dest_point
	if dest is NodePath:
		dest_point = get_node(dest).global_transform.origin
	elif dest is Spatial:
		dest_point = dest.global_transform.origin
	else:
		dest_point = dest
	
	path_point = 0
	wanted_speed = speed
	original_pathway = get_node(navigation_node).get_simple_path(global_transform.origin, dest_point, true)
	pathway = original_pathway
	yield(get_tree(),"idle_frame")
	active = true

func _physics_process(delta):
	if !Engine.editor_hint:
		if !show_agent_arrow:
			FLine.clear()
			print_arrow = true
		if pathway:
			if draw_path:
				path.clear()
				path.begin(Mesh.PRIMITIVE_LINE_STRIP, null)
				for point in pathway.size():
					path.add_vertex(pathway[point])
				path.end()
			else:
				path.clear()
			var dist
			if slide == 0:
				dist = 1.5+(speed*0.08)
			else:
				dist = (0.5/slide)+(0.55*slide)+(avoid_speed*0.3)
			dist = clamp(dist, 1.5, 10)
			if (global_transform.origin-pathway[path_point]).length() < dist:
				if path_point+1 < pathway.size():
					path_point += 1
					wanted_speed = speed
				else:
					wanted_speed = 0
			look_towards.look_at(pathway[path_point], Vector3.UP)
			look_to = rotation_degrees.y + look_towards.rotation_degrees.y
			rotation_degrees.y = lerp(rotation_degrees.y, look_to, delta*turn)
			if slide == 0:
				cur_turn = rotation_degrees.y
			elif is_on_wall():
				cur_turn = lerp(cur_turn, rotation_degrees.y, (delta/slide)*(slide_kill*5))
				cur_speed -= slide_kill*0.01
			elif slide != 0:
				if rotation_degrees.y > cur_turn+180:
					cur_turn += 360 
				elif rotation_degrees.y < cur_turn-180:
					cur_turn -= 360 
				cur_turn = lerp(cur_turn, rotation_degrees.y, (delta/slide)*10)
				var speed_reduction = rotation_degrees.y - cur_turn
				if speed_reduction < 0:
					speed_reduction = -speed_reduction
				cur_speed -= speed_reduction*0.001
			slider.rotation_degrees.y = cur_turn
			cur_speed = clamp(cur_speed, 0, 99)
			cur_speed = lerp(cur_speed, wanted_speed, acceleration*delta)
			if is_on_floor():
				cur_gravity.y = 0
			else:
				cur_gravity.y += gravity*delta
			avoid_speed -= delta*(avoidance*1.5)
			avoid_speed = clamp(avoid_speed, 0, avoidance*3)
			move_and_slide(slider.transform.basis.xform(Vector3.FORWARD*(cur_speed + avoid_speed)) - cur_gravity, Vector3.UP)
		else:
			cur_turn = rotation_degrees.y
			get_parent().add_child(slider)
			add_child(look_towards)
			get_parent().add_child(path)
			if destination:
				Set_Destination(destination)
	else:
		if print_arrow:
			print_arrow = false
			show_arrow()

func _process(delta):
	if Engine.editor_hint:
		if create_core_nodes:
			create_core_nodes = false
			var new_collider = CollisionShape.new()
			new_collider.shape = CapsuleShape.new()
			var new_mesh = MeshInstance.new()
			new_mesh.mesh = CapsuleMesh.new()
			self.add_child(new_collider)
			self.add_child(new_mesh)
			new_collider.owner = owner
			new_mesh.owner = owner
			new_collider.rotation_degrees.x = 270
			new_mesh.rotation_degrees.x = 270
