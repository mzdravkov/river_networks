require "tree"
require "gnuplot"
require "geometry"

require "./Splines/srcs_ruby_interface/Splines_ffi.rb"

include Geometry

def euclidean_distance(p1, p2)
  Math.sqrt((p1[0] - p2[0])**2 + (p1[1] - p2[1])**2)
end

# returns the two points that are nearest to the point
def nearest_two(points, point)
  distances = points.map { |p| euclidean_distance(p, point) }
  min_dist1 = min_dist2 = Float::INFINITY
  point1 = point2 = nil

  for i in 0...points.count
    next if distances[i] == 0
    if distances[i] < min_dist1
      min_dist1 = distances[i]
      point1 = i
    elsif distances[i] < min_dist2
      min_dist2 = distances[i]
      point2 = i
    end
    if min_dist1 < min_dist2
      min_dist1, min_dist2 = min_dist2, min_dist1
      point1, point2 = point2, point1
    end
  end
  return points[point1], points[point2]
end

def line_by_coords x1, y1, x2, y2
  [(y2-y1)/(x2-x1), (x2*y1-x1*y2)/(x2-x1)]
end

def line p1, p2
  line_by_coords p1[0], p1[1], p2[0], p2[1]
end

# returns the y value of line at the given x
def y_at line, x
  line[0] * x + line[1]
end

def point_on_line line, x
  [x, y_at(line, x)]
end

# returns true if AB X CD
def intersect a, b, c, d
  line1 = Segment.new_by_arrays(a, b)
  line2 = Segment.new_by_arrays(c, d)

  line1.intersects_with? line2
end

# returns the intersection points of AB and CD
# or nil if they don't intersect
def intersection a, b, c, d
  line1 = Segment.new_by_arrays(a, b)
  line2 = Segment.new_by_arrays(c, d)
  return nil unless line1.intersects_with?(line2)
  intersection = line1.intersection_point_with(line2)
  [intersection.x, intersection.y]
end

# returns the vertices of the polygon, which is the area defined by the limits.
def find_area limits, x_max, y_max
  last_limit, previous_limit = limits[-1], limits[-2]

  mouth = [x_max/2.0, 0.0]
  bottom_left, top_left = [0.0, 0.0], [0.0, y_max]
  bottom_right, top_right = [x_max, 0.0], [x_max, y_max]

  direction = if last_limit[0] * previous_limit[0] >= 0
    if previous_limit[0] >= 0
      previous_limit[0] >= last_limit[0] ? :right : :left
    else
      last_limit[0] >= previous_limit[0] ? :left : :right
    end
  else
    previous_limit[0] >= 0 ? :left : :right
  end

  area = if i = intersection(bottom_left, top_left, mouth, point_on_line(last_limit, 0.0)) # left
    if direction == :left
      [i, mouth, bottom_left]
    else
      [i, top_left, top_right, bottom_right, mouth]
    end
  elsif i = (intersection(top_left, top_right, mouth, point_on_line(last_limit, 0.0)) or # top
             intersection(top_left, top_right, mouth, point_on_line(last_limit, x_max)))
    if direction == :left
      [i, mouth, bottom_left, top_left]
    else
      [i, top_right, bottom_right, mouth]
    end
  elsif i = intersection(bottom_right, top_right, mouth, point_on_line(last_limit, x_max)) # right
    if direction == :left
      [i, mouth, bottom_left, top_left, top_right]
    else
      [i, bottom_right, mouth]
    end
  else
    #TODO: find why this is happening
    puts "Error: The limit doesn't intersect anything. Try again, this was a bad luck."
    exit(1)
  end

  area.uniq
end

# returns true if the point is within the bounds of the polygon
def point_in_polygon?(point, poly)
  vertices = poly.map { |v| Point(v[0], v[1]) }
  area = Geometry::Polygon.new(vertices)
  return area.contains?(Point(point[0], point[1]))
end

def algorithm points, x_max, y_max
  network = Tree::TreeNode.new("root", {pos: points[0]})
  id = 0
  area_limits = []
  current = network
  p1, p2 = nearest_two(points, points[0])

  add_next_point_and_limit = lambda do
    # get the centroid of p1 and p2
    new_x = (p1[0] + p2[0])/2.0
    new_y = (p1[1] + p2[1])/2.0
    id += 1
    # create a Node for the new point
    new_point = Tree::TreeNode.new(id.to_s, {pos: [new_x, new_y]})
    # add the new point to be child of current
    current << new_point

    # adding new limit (a line through the mouth and the new point)
    area_limits << line(network.content[:pos], new_point.content[:pos])
    points.delete_if { |elem| elem == p1 or elem == p2 }

    current = new_point
  end

  add_next_point_and_limit.call
  points.delete_at 0

  while !points.empty?
    if area_limits.count == 1
      # if there is only one limit we go to whatever direction is the centroid
      # of the nearest two points
      break if points.count == 1
      p1, p2 = nearest_two(points, current.content[:pos])
    else
      # when we have more limits we know the direction they imply and look
      # for points in that area only
      area = find_area(area_limits, x_max, y_max)
      points_in_area = points.select { |p| point_in_polygon?(p, area) }
      # if no points in the area we delete the last limit and return one step backward
      if points_in_area.empty?
        area_limits.pop
        current = current.parent
        next
      end
      # if only one point, we delete it
      # originally, I generated random second point, but this can lead to intersections between rivers
      if points_in_area.count == 1
        points.delete_if { |p| p == points_in_area[0] }
        next
      end
      p1, p2 = nearest_two(points_in_area, current.content[:pos])
    end

    add_next_point_and_limit.call
  end

  return network
end

def recursive_plot(node, plot, branches_colors)
  return if node.is_leaf?
  node.children.each do |child|
    data = [[node.content[:pos][0], child.content[:pos][0]], [node.content[:pos][1], child.content[:pos][1]]]
    plot.data << Gnuplot::DataSet.new(data) do |ds|
      ds.with = "lines"
      ds.linewidth = child.content[:width]
      ds.notitle
      ds.linecolor = "rgbcolor \"##{branches_colors[child.content['branch']]}\""
    end
    recursive_plot(child, plot, branches_colors)
  end
end

# this makes rivers with many influxes
# to be drawn with thicker lines
def set_rivers_widths(network)
  if network.is_leaf?
    return network.content[:width] = 1
  else
    children_widths = []
    network.children.each do |r|
      width = set_rivers_widths(r)
      children_widths << width
    end
    max = children_widths.max
    size = max
    size += 1 if children_widths.count(max) > 1
    return network.content[:width] = size
  end
end

def branches(node, branch, branches)
  branch << node
  node.content['branch'] = branch.object_id
  return branches << branch if node.children.empty?

  successor = node.children.max_by { |c| c.size }
  node.children.each do |child|
    if child == successor
      branches(child, branch, branches)
    else
      branches(child, Array.new, branches)
    end
  end

  return branches
end

x_max = 1000.0
y_max = 1000.0
num_points = ARGV.empty? ? 100 : ARGV.first.to_i

points = [[x_max/2, 0]] + (1...num_points).map { [rand(x_max), rand(y_max)] }.uniq

river_network = algorithm(points, x_max, y_max)

root_width = set_rivers_widths(river_network)
river_network.content[:width] = root_width

river_branches = branches(river_network, [], [])

river_branches.each { |branch| p "new:"; branch.each { |n| p n.content } }

colors = river_branches.map { rand(256).to_s(16) + rand(256).to_s(16) + rand(256).to_s(16) }
branches_colors = Hash[river_branches.map(&:object_id).zip(colors)]

Gnuplot.open do |gp|
  Gnuplot::Plot.new( gp ) do |plot|

    plot.title  "River network"
    plot.xlabel "x"
    plot.ylabel "y"

    recursive_plot(river_network, plot, branches_colors)
  end
end



spline = Spline.new

# xx0.zip(yy0).each { |p| p p ; spline.push_back(p[0],p[1]) }

# spline.build
