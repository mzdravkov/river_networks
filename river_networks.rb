require "tree"
require "gnuplot"
require "geometry"

def euclidean_distance(p1, p2)
  Math.sqrt((p1[0] - p2[0])**2 + (p1[1] - p2[1])**2)
end

def nearest_two(points, point)
  distances = points.map { |p| euclidean_distance(p, point) }
  min_dist1 = min_dist2 = Float::INFINITY
  point1 = point2 = 0
  for i in 0...points.count
    next if distances[i] == 0
    if distances[i] < min_dist1
      min_dist1 = distances[i]
      point1 = i
    elsif distances[i] < min_dist2
      min_dist2 = distances[i]
      point2 = i
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

def find_area limits, x_max, y_max
  last_limit, previous_limit = limits[-1], limits[-2]

  direction = if last_limit[0] * previous_limit[0] >= 0
    if previous_limit[0] >= 0
      if previous_limit[0] - last_limit[0] >= 0
        "right"
      else
        "left"
      end
    else
      if last_limit[0] - previous_limit[0] >= 0
        "left"
      else
        "rigth"
      end
    end
  else
    if previous_limit[0] >= 0
      "left"
    else
      "rigt"
    end
  end

  # top line intersection
  top_intersection_x = (y_max-last_limit[1])/last_limit[0] if last_limit[0] != 0
  #check if last limit intersects the left line of the box
  area = if last_limit[1] <= y_max and last_limit[1] >= 0
    intersection = [0, last_limit[1]]
    if direction == "left"
      [[0, 0],
       [x_max/2, 0],
        intersection]
    else
      [[x_max/2, 0],
       [x_max, 0],
       [x_max, y_max],
       [0, y_max],
       intersection]
    end
  elsif last_limit[0] != 0 and 0 <= top_intersection_x and top_intersection_x >= x_max # if intersects the top
    intersection = [top_intersection_x, y_max]
    if direction == "left"
      [[0, 0],
       [x_max/2, 0],
       intersection,
       [0, y_max]]
    else
      [[x_max/2, 0],
       [x_max, 0],
       [x_max, y_max],
       intersection]
    end
  else # and the right
    intersection = [x_max, -1*last_limit[1]]
    if direction == "left"
      [[0, 0],
       [x_max/2, 0],
       intersection,
       [x_max, y_max],
       [0, y_max]]
    else
      [[x_max/2, 0],
       [x_max, 0],
       intersection]
    end
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

  p1, p2 = nearest_two(points, points[0])
  new_x = (p1[0] + p2[0])/2
  new_y = (p1[1] + p2[1])/2
  id = 1
  new_point = Tree::TreeNode.new(id.to_s, {pos: [new_x, new_y]})
  network << new_point

  area_limits = [line(points[0], new_point.content[:pos])]
  points.delete_at 0
  points.delete_if { |elem| elem == p1 or elem == p2}

  current = new_point
  while !points.empty?
    if area_limits.length == 1  
      p1, p2 = nearest_two(points, current.content[:pos])
    else
      points_in_area = points.select { |p| point_in_polygon(p, find_area(area_limits, x_max, y_max)) }
      if points_in_area.empty?
        area_limits.pop
        current = current.parent
        next
      end
      p1, p2 = nearest_two(points_in_area, current.content[:pos])
    end

    new_x = (p1[0] + p2[0])/2
    new_y = (p1[1] + p2[1])/2
    id += 1
    new_point = Tree::TreeNode.new(id.to_s, {pos: [new_x, new_y]})
    current << new_point

    area_limits << line(network.content[:pos], new_point.content[:pos])
    points.delete_if { |elem| elem == p1 or elem == p2}

    current = new_point
  end

  return network
end

x_max = 100.0
y_max = 100.0
num_points = 100

points = [[x_max/2, 0]] + (1...num_points).map { [rand(x_max), rand(y_max)] }.uniq

river_network = algorithm(points, x_max, y_max)
river_network.print_tree

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