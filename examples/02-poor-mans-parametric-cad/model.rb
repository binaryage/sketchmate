# frozen_string_literal: true

# @param [Regexp] patern
def find_all_by_name_match(pattern)
  Sketchup.active_model.entities.find_all { |e| e.name =~ pattern if e.respond_to?(:name) }
end

# @param [String] name
def lookup_by_name(name)
  hit = Sketchup.active_model.entities.find { |e| e.name == name if e.respond_to?(:name) }
  raise "Unable to find entity with name '#{name}'" if hit.nil?

  hit
end

# @param [String] name
# @return [Sketchup::Group] group
def lookup_group_by_name(name)
  hit = lookup_by_name(name)
  raise "Not a group #{hit}" unless hit.is_a? Sketchup::Group

  hit
end

# @param [String] name
def erase_by_name(name)
  hits = Sketchup.active_model.entities.find_all { |e| e.name == name if e.respond_to?(:name) }
  return if hits.empty?

  Sketchup.active_model.entities.erase_entities(hits)
end

# @param [Sketchup::Group] group
# @param [Object] x
# @param [Object] y
# @param [Object] z
def set_position(group, x, y, z)
  point = Geom::Point3d.new(x, y, z)
  tr = Geom::Transformation.new(point)
  group.transformation = tr
end

# @param [Sketchup::Group] group
def flatten_group(group)
  group.entities.each do |e|
    next if e.deleted?
    next unless e.is_a? Sketchup::Group

    e.explode
  end
end

def compute_window
  model = Sketchup.active_model
  begin
    model.start_operation('Compute Window', true)

    hole_name = '[computed] window hole'
    erase_by_name(hole_name)

    border_name = '[computed] window border'
    erase_by_name(border_name)

    template_window = lookup_group_by_name('window')

    window = template_window.copy
    window.make_unique
    window.name = hole_name
    window.layer = '01-computed'
    displacement = Geom::Vector3d.new(10.m, 0, 0)
    t = Geom::Transformation.translation(displacement)
    window.move!(template_window.transformation * t)
    faces = window.entities.grep(Sketchup::Face)
    # @type [Sketchup::Face]
    hole_face = faces[0]
    hole_face.pushpull(-0.3.m)
    # @type [Sketchup::Face]
    profile_face = faces[1]
    window.entities.erase_entities(profile_face.all_connected)

    window = template_window.copy
    window.make_unique
    window.name = border_name
    window.layer = '01-computed'
    displacement = Geom::Vector3d.new(12.m, 0, 0)
    t = Geom::Transformation.translation(displacement)
    window.move!(template_window.transformation * t)

    faces = window.entities.grep(Sketchup::Face)
    # @type [Sketchup::Face]
    hole_face = faces[0]
    # @type [Sketchup::Face]
    profile_face = faces[1]

    edges = hole_face.outer_loop.edges
    puts "follow me edges => ##{edges.count}"

    result = profile_face.followme(edges)
    puts "follow me result => #{result}"

    window.entities.erase_entities(hole_face.all_connected)

    model.commit_operation
  rescue StandardError
    model.abort_operation
    raise
  end
end

def compute_walls
  model = Sketchup.active_model
  model.start_operation('Compute Walls', true)
  begin
    name = '[computed] walls'
    erase_by_name(name)
    template_walls = lookup_group_by_name('walls')
    walls = template_walls.copy
    walls.make_unique
    walls.name = name
    walls.layer = '02-computed'
    set_position(walls, 21.m, 1.m, 0)

    insertion_points_group = walls.entities.grep(Sketchup::Group)[0]
    points = insertion_points_group.entities
    path = "#{walls.persistent_id}.#{insertion_points_group.persistent_id}"
    ipath = model.instance_path_from_pid_path(path)

    template_window_hole = lookup_group_by_name('[computed] window hole')
    template_window_border = lookup_group_by_name('[computed] window border')

    holes = []
    borders = []
    # @param [Sketchup::ComponentInstance] point
    points.each do |point|
      raise '!' unless point.is_a? Sketchup::ComponentInstance

      t = ipath.transformation * point.transformation
      hole = template_window_hole.copy
      hole.make_unique
      hole.name = '[computed] hole'
      hole.layer = '02-computed'
      hole.transformation = t

      border = template_window_border.copy
      border.make_unique
      border.name = '[computed] border'
      border.layer = '02-computed'
      border.transformation = t

      holes << hole
      borders << border
    end

    insertion_points_group.erase!

    # finally perform boolean operations:
    # a) subtract window holes
    # b) union with window borders
    difference = walls
    puts "holes: ##{holes.count}"
    holes.each do |hole|
      difference = hole.subtract(difference)
    end
    difference.name = '[computed] wall with holes'

    union = difference
    puts "borders: ##{borders.count}"
    borders.each do |border|
      union = union.union(border)
    end
    union.name = '[computed] wall'
    union.layer = '02-computed'

    model.commit_operation
  rescue StandardError
    model.abort_operation
    raise
  end
end

def clean
  computed_entities = find_all_by_name_match(/\[computed\]/)
  Sketchup.active_model.entities.erase_entities(computed_entities)
end

def compute
  compute_window
  compute_walls
end

# change this to true if you want model to be automatically recomputed on load
if false
  clean
  compute
end