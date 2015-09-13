require "tree"
require "gnuplot"
require "geometry"

include Geometry

def euclidean_distance(p1, p2)
  Math.sqrt((p1[0] - p2[0])**2 + (p1[1] - p2[1])**2)
end

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

def intersection a, b, c, d
  line1 = Segment.new_by_arrays(a, b)
  line2 = Segment.new_by_arrays(c, d)
  return nil unless line1.intersects_with?(line2)
  intersection = line1.intersection_point_with(line2)
  [intersection.x, intersection.y]
end

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
    puts "Error: The limit doesn't intersect anything."
    exit(1)
  end

  area.uniq
end

def point_in_polygon(point, poly)
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
  inters = []

  add_next_point_and_limit = lambda do
    new_x = (p1[0] + p2[0])/2.0
    new_y = (p1[1] + p2[1])/2.0
    id += 1
    new_point = Tree::TreeNode.new(id.to_s, {pos: [new_x, new_y]})
    current << new_point

    area_limits << line(network.content[:pos], new_point.content[:pos])
    points.delete_if { |elem| elem == p1 or elem == p2 }

    current = new_point
  end

  add_next_point_and_limit.call
  points.delete_at 0

  while !points.empty?
    if area_limits.count == 1
      break if points.count == 1
      p1, p2 = nearest_two(points, current.content[:pos])
    else
      area = find_area(area_limits, x_max, y_max)
      points_in_area = points.select { |p| point_in_polygon(p, area) }
      if points_in_area.empty?
        area_limits.pop
        current = current.parent
        next
      end
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

def recursive_plot(node, plot)
  return if node.is_leaf?
  node.children.each do |child|
    data = [[node.content[:pos][0], child.content[:pos][0]], [node.content[:pos][1], child.content[:pos][1]]]
    plot.data << Gnuplot::DataSet.new(data) do |ds|
      ds.with = "lines"
      ds.linewidth = child.content[:width]
      ds.notitle
    end
    recursive_plot(child, plot)
  end
end

def set_rivers_widths(network)
  if network.is_leaf?
    network.content[:width] = 1
    return 1
  else
    children_widths = []
    network.children.each do |r|
      width = set_rivers_widths(r)
      children_widths << width
    end
    unique = children_widths.uniq.sort
    current = unique.length - 1
    while current >= 0
      return network.content[:width] = unique[current] + 1 if children_widths.count(unique[current]) >= 2
      current -= 1
    end
    return network.content[:width] = unique[-1]
  end
end

x_max = 1000.0
y_max = 1000.0
num_points = ARGV.empty? ? 100 : ARGV.first.to_i

points = [[x_max/2, 0]] + (1...num_points).map { [rand(x_max), rand(y_max)] }.uniq

river_network = algorithm(points, x_max, y_max)

root_width = set_rivers_widths(river_network)
river_network.content[:width] = root_width

Gnuplot.open do |gp|
  Gnuplot::Plot.new( gp ) do |plot|

    plot.title  "River network"
    plot.xlabel "x"
    plot.ylabel "y"

    recursive_plot(river_network, plot)
  end
end
