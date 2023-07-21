# frozen_string_literal: true

model = Sketchup.active_model
model.start_operation('Create Cube', true)
group = model.active_entities.add_group
entities = group.entities
points = [
  Geom::Point3d.new(0, 0, 0),
  Geom::Point3d.new(1.m, 0, 0),
  Geom::Point3d.new(1.m, 1.m, 0),
  Geom::Point3d.new(0, 1.m, 0)
]
face = entities.add_face(points)
face.pushpull(-1.m)

dist_x = rand(-200..200)
dist_y = rand(-200..200)
displacement = Geom::Vector3d.new(dist_x, dist_y, 0)
t = Geom::Transformation.translation(displacement)
group.transform!(t)

model.commit_operation

if false
  Sketchup.active_model.active_entities.each(&:erase!)
end
