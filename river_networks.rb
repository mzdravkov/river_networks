require "tree"

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

def algorithm points
  network = Tree::TreeNode.new("root", points[0])

  p1, p2 = nearest_two(points, points[0])
  new_x = (p1[0] + p2[0])/2
  new_y = (p1[1] + p2[1])/2
  new_point = Tree::TreeNode.new("node", [new_x, new_y])
  network << new_point

  area_limits = [line(points[0], [new_x, new_y])]
  points.delete_at 0
  points.delete_if { |elem| elem == p1 or elem == p2}

  current = new_point

  p1, p2 = nearest_two(points, current.content)
  new_x = (p1[0] + p2[0])/2
  new_y = (p1[1] + p2[1])/2
  new_point = Tree::TreeNode.new("node", [new_x, new_y])
  current << new_point

  area_limits = [line(current.content, [new_x, new_y])]
  points.delete_if { |elem| elem == p1 or elem == p2}

  current = new_point
  while !points.empty?
    p1, p2 = nearest_two(points, current.content)

    new_x = (p1[0] + p2[0])/2
    new_y = (p1[1] + p2[1])/2
    new_point = Tree::TreeNode.new("node", [new_x, new_y])
    current << new_point

    area_limits = [line(current.content, [new_x, new_y])]
    points.delete_if { |elem| elem == p1 or elem == p2}

    current = new_point
  end

  return network
end

x_max = 100
y_max = 100
num_points = 21

points = [[x_max/2, 0]] + (1...num_points).map { [rand(x_max), rand(y_max)] }.uniq

river_network = algorithm(points)
river_network.print_tree