#![forbid(unsafe_code)]

/// Documentation for main
fn main() {
    let result = add(1, 2);
    println!("Result: {}", result);
}

/// Add two numbers
fn add(a: i32, b: i32) -> i32 {
    a.saturating_add(b)
}

struct Config {
    value: i32,
}

impl Config {
    fn new() -> Self {
        Config { value: 42 }
    }
}
