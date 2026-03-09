//! Demo module showcasing strict Rust standards compliance.
//! This file demonstrates safe, no-alloc, no-unsafe Rust patterns.

#![forbid(unsafe_code)]
#![forbid(unused_variables)]
#![forbid(unused_mut)]

/// Represents a simple 2D point with i32 coordinates.
/// Using i32 instead of usize for more predictable behavior.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Point {
    x: i32,
    y: i32,
}

impl Point {
    /// Creates a new point with given coordinates.
    #[must_use]
    pub const fn new(x: i32, y: i32) -> Self {
        Self { x, y }
    }

    /// Returns the x coordinate.
    #[must_use]
    pub const fn x(self) -> i32 {
        self.x
    }

    /// Returns the y coordinate.
    #[must_use]
    pub const fn y(self) -> i32 {
        self.y
    }

    /// Calculates squared distance to another point (avoids sqrt).
    #[must_use]
    pub fn squared_distance_to(self, other: Point) -> i32 {
        let dx = self.x.saturating_sub(other.x);
        let dy = self.y.saturating_sub(other.y);
        dx.saturating_mul(dx).saturating_add(dy.saturating_mul(dy))
    }
}

/// A bounded integer that wraps around at boundaries.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct BoundedInt {
    value: i32,
    min: i32,
    max: i32,
}

impl BoundedInt {
    /// Creates a new bounded integer.
    #[must_use]
    pub fn new(value: i32, min: i32, max: i32) -> Self {
        let clamped = value.clamp(min, max);
        Self { value: clamped, min, max }
    }

    /// Gets the current value.
    #[must_use]
    pub const fn get(self) -> i32 {
        self.value
    }

    /// Increments value with saturation at maximum.
    pub fn increment(&mut self) {
        self.value = self.value.saturating_add(1).clamp(self.min, self.max);
    }

    /// Decrements value with saturation at minimum.
    pub fn decrement(&mut self) {
        self.value = self.value.saturating_sub(1).clamp(self.min, self.max);
    }
}

/// Result type for demo operations.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DemoResult {
    Success,
    InvalidInput,
    OutOfBounds,
}

/// A simple rectangle defined by two corner points.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Rectangle {
    top_left: Point,
    bottom_right: Point,
}

impl Rectangle {
    /// Creates a new rectangle from two points.
    #[must_use]
    pub fn new(p1: Point, p2: Point) -> Self {
        let x1 = p1.x().min(p2.x());
        let y1 = p1.y().min(p2.y());
        let x2 = p1.x().max(p2.x());
        let y2 = p1.y().max(p2.y());
        Self {
            top_left: Point::new(x1, y1),
            bottom_right: Point::new(x2, y2),
        }
    }

    /// Checks if a point is inside the rectangle (boundary inclusive).
    pub fn contains(self, point: Point) -> bool {
        point.x() >= self.top_left.x()
            && point.x() <= self.bottom_right.x()
            && point.y() >= self.top_left.y()
            && point.y() <= self.bottom_right.y()
    }

    /// Returns the area of the rectangle using saturating arithmetic.
    #[must_use]
    pub fn area(self) -> i32 {
        let width = self.bottom_right.x().saturating_sub(self.top_left.x());
        let height = self.bottom_right.y().saturating_sub(self.top_left.y());
        width.saturating_mul(height)
    }
}

/// Demonstrates basic point operations.
pub fn demo_point_operations() -> [Point; 3] {
    let p1 = Point::new(0, 0);
    let p2 = Point::new(3, 4);
    let p3 = Point::new(-1, 5);

    let _distance_sq = p1.squared_distance_to(p2);

    [p1, p2, p3]
}

/// Demonstrates bounded integer operations.
pub fn demo_bounded_int() -> BoundedInt {
    let mut value = BoundedInt::new(5, 0, 10);

    value.increment();
    value.increment();
    value.decrement();

    value
}

/// Demonstrates rectangle operations.
pub fn demo_rectangle_operations() -> (Rectangle, bool) {
    let rect = Rectangle::new(Point::new(0, 0), Point::new(10, 5));
    let point_inside = Point::new(5, 3);
    let point_outside = Point::new(15, 15);

    let inside = rect.contains(point_inside);
    let _outside = rect.contains(point_outside);
    let _area = rect.area();

    (rect, inside)
}

/// Main demonstration function.
pub fn run_demo() -> DemoResult {
    let _points = demo_point_operations();
    let _bounded = demo_bounded_int();
    let (_rect, _contains) = demo_rectangle_operations();

    DemoResult::Success
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_point_creation() {
        let p = Point::new(3, 4);
        assert_eq!(p.x(), 3);
        assert_eq!(p.y(), 4);