//Takes click params as input, returns a vector2 of pixel location relative to client lowerleft corner
/proc/get_screen_pixel_click_location(var/params)
	var/screen_loc = params2list(params)["screen-loc"]
	/* This regex matches a screen-loc of the form
			"[tile_x]:[step_x],[tile_y]:[step_y]"
		given by the "params" argument of the mouse events.
	*/
	var global/regex/ScreenLocRegex = regex("(\\d+):(\\d+),(\\d+):(\\d+)")
	var/vector2/position = new /vector2(0,0)
	if(ScreenLocRegex.Find(screen_loc))
		var list/data = ScreenLocRegex.group
		//position.x = text2num(data[2]) + (text2num(data[1])) * world.icon_size
		//position.y = text2num(data[4]) + (text2num(data[3])) * world.icon_size

		position.x = text2num(data[2]) + (text2num(data[1]) - 1) * world.icon_size
		position.y = text2num(data[4]) + (text2num(data[3]) - 1) * world.icon_size

	return position

//Gets a global-context pixel location. This requires a client to use
/proc/get_global_pixel_click_location(var/params, var/client/client)
	var/vector2/world_loc = new /vector2(0,0)
	if (!client)
		return world_loc

	world_loc = get_screen_pixel_click_location(params)
	world_loc = client.ViewportToWorldPoint(world_loc)
	return world_loc

//This mildly complicated proc attempts to move thing to where the user's mouse cursor is
//Thing must be an atom that is already onscreen - ie, in a client's screen list
/proc/sync_screen_loc_to_mouse(var/atom/movable/thing, var/params, var/tilesnap = FALSE, var/vector2/offset = Vector2.Zero)
	var/screen_loc = params2list(params)["screen-loc"]
	var/global/regex/ScreenLocRegex = regex("(\\d+):(\\d+),(\\d+):(\\d+)")
	if(ScreenLocRegex.Find(screen_loc))
		var/list/data = ScreenLocRegex.group
		if (!tilesnap)
			thing.screen_loc = "[data[1]]:[text2num(data[2])+offset.x],[data[3]]:[text2num(data[4])+offset.y]"
		else
			thing.screen_loc = "[data[1]]:[offset.x],[data[3]]:[offset.y]"
		//This will fill screen loc with a string in the form:
			//"TileX:PixelX,TileY:PixelY"






/atom/proc/get_global_pixel_loc()
	return new /vector2(((x-1)*world.icon_size) + pixel_x + 16, ((y-1)*world.icon_size) + pixel_y + 16)



//Given a set of global pixel coords as input, this moves the atom and sets its pixel offsets so that it sits exactly on the specified point
/atom/movable/proc/set_global_pixel_loc(var/vector2/coords)

	var/vector2/tilecoords = new /vector2(round(coords.x / world.icon_size)+1, round(coords.y / world.icon_size)+1)
	forceMove(locate(tilecoords.x, tilecoords.y, z))
	pixel_x = (coords.x % world.icon_size)-16
	pixel_y = (coords.y % world.icon_size)-16


//Takes pixel coordinates relative to a tile. Returns true if those coords would offset an object to outside the tile
/proc/is_outside_cell(var/vector2/newpix)
	if (newpix.x < -16 || newpix.x > 16 || newpix.y < -16 || newpix.y > 16)
		return TRUE

//Takes pixel coordinates relative to a tile. Returns true if those coords would offset an object to more than 8 pixels into an adjacent tile
/proc/is_far_outside_cell(var/vector2/newpix)
	if (newpix.x < -24 || newpix.x > 24 || newpix.y < -24 || newpix.y > 24)
		return TRUE

//Returns the turf over which the mob's view is centred. Only relevant if view offset is set
/mob/proc/get_view_centre()
	if (!view_offset)
		return get_turf(src)

	var/vector2/offset = (Vector2.FromDir(dir))*view_offset
	return get_turf_at_pixel_offset(offset)


//Returns the turf over which the mob's view is centred. Only relevant if view offset is set
/client/proc/get_view_centre()
	return mob.get_view_centre()

//Given a pixel offset relative to this atom, finds the turf under the target point.
//This does not account for the object's existing pixel offsets, roll them into the input first if you wish
/atom/proc/get_turf_at_pixel_offset(var/vector2/newpix)
	//First lets just get the global pixel position of where this atom+newpix is
	var/vector2/new_global_pixel_loc = new /vector2(((x-1)*world.icon_size) + newpix.x + 16, ((y-1)*world.icon_size) + newpix.y + 16)

	return get_turf_at_pixel_coords(new_global_pixel_loc, z)



//Global version of the above, requires a zlevel to check on
/proc/get_turf_at_pixel_coords(var/vector2/coords, var/zlevel)
	coords = new /vector2(round(coords.x / world.icon_size)+1, round(coords.y / world.icon_size)+1)
	return locate(coords.x, coords.y, zlevel)

/proc/get_turf_at_mouse(var/clickparams, var/client/C)
	var/vector2/pixels = get_global_pixel_click_location(clickparams, C)
	return get_turf_at_pixel_coords(pixels, C.mob.z)

//Client Procs

//This proc gets the client's total pixel offset from its eyeobject
/client/proc/get_pixel_offset()
	var/vector2/offset = new /vector2(0,0)
	if (ismob(eye))
		var/mob/M = eye
		offset = (Vector2.FromDir(M.dir))*M.view_offset

	offset.x += pixel_x
	offset.y += pixel_y

	return offset


//Figures out the offsets of the bottomleft and topright corners of the game window
/client/proc/get_pixel_bounds()
	var/radius = view*world.icon_size
	var/vector2/bottomleft = new /vector2(-radius, -radius)
	var/vector2/topright = new /vector2(radius, radius)
	var/vector2/offset = get_pixel_offset()
	bottomleft += offset
	topright += offset

	return list("BL" = bottomleft, "TR" = topright, "OFFSET" = offset)


//Figures out the offsets of the bottomleft and topright corners of the game window in tiles
//There are no decimal tiles, it will always be a whole number. Partially visible tiles can be included or excluded
/client/proc/get_tile_bounds(var/include_partial = TRUE)
	var/list/bounds = get_pixel_bounds()
	for (var/thing in bounds)
		var/vector2/corner = bounds[thing]
		corner /= WORLD_ICON_SIZE
		if (include_partial)
			corner = corner.CeilingVec()
		else
			corner = corner.FloorVec()
		bounds[thing] = corner
	return bounds


/atom/proc/set_offset_to(var/atom/target, var/distance)
	pixel_x = 0
	pixel_y = 0
	offset_to(target, distance)

/atom/proc/offset_to(var/atom/target, var/distance)
	var/vector2/delta = get_offset_to(target, distance)
	pixel_x += delta.x
	pixel_y += delta.y


/atom/proc/get_offset_to(var/atom/target, var/distance)
	var/vector2/delta = Vector2.FromDir(get_dir(src, target))
	delta *= distance
	return delta