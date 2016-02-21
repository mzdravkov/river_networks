def zeros(n)
  return [0]*n
end

# function cubic_spline(n, xn) interpolates between the knots
# specified by lists xn and a. The function computes the coefficients
# and outputs the ranges of the piecewise cubic splines.
#INPUT: n; x0, x1, ... ,xn; a0 = f(x0), a1 =f(x1), ... , an = f(xn).
def cubic_spline(n, xn, a)
  h = zeros(n-1)

  # alpha will be values in a system of eq's that will allow us to solve for c
  # and then from there we can find b, d through substitution.
  alpha = zeros(n-1)

  # l, u, z are used in the method for solving the linear system
  l = zeros(n+1)
  u = zeros(n)
  z = zeros(n+1)

  # b, c, d will be the coefficients along with a.
  b = zeros(n)
  c = zeros(n+1)
  d = zeros(n)

  for i in 0...n-1
    # h[i] is used to satisfy the condition that
    # Si+1(xi+l) = Si(xi+l) for each i = 0,..,n-1
    # i.e., the values at the knots are "doubled up"
    h[i] = xn[i+1]-xn[i]
  end

  for i in 1...n-1
    # Sets up the linear system and allows us to find c.  Once we have
    # c then b and d follow in terms of it.
    alpha[i] = (3.0/h[i])*(a[i+1]-a[i])-(3.0/h[i-1])*(a[i] - a[i-1])
  end

  # I, II, (part of) III Sets up and solves tridiagonal linear system...
  # I
  l[0] = 1
  u[0] = 0
  z[0] = 0

  # II
  for i in 1...n-1
    l[i] = 2*(xn[i+1] - xn[i-1]) - h[i-1]*u[i-1]
    u[i] = h[i]/l[i]
    z[i] = (alpha[i] - h[i-1]*z[i-1])/l[i]
  end

  l[n] = 1
  z[n] = 0
  c[n] = 0

  # III... also find b, d in terms of c.
  (n-2).downto(-1) do |j|
    c[j] = z[j] - u[j]*c[j+1]
    b[j] = (a[j+1] - a[j])/h[j] - h[j]*(c[j+1] + 2*c[j])/3.0
    d[j] = (c[j+1] - c[j])/(3*h[j])
  end

  # original sends xn also
  return [a, b, c, d]
end
