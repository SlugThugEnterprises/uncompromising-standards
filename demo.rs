#![forbid(unsafe_code)]

fn main() {
    println!("Starting demo");
    let data = vec![1, 2, 3, 4, 5];
    for i in data.iter() {
        println!("Value: {}", i);
    }
}

fn process_data() {
    let mut map = std::collections::HashMap::new();
    map.insert("key1", "value1");
    map.insert("key2", "value2");
    for (k, v) in map.iter() {
        println!("{} = {}", k, v);
    }
}

fn calculate() {
    let a = 10;
    let b = 20;
    let c = a + b;
    println!("Result: {}", c);
}

fn handle_error() {
    let result: Result<i32, &str> = Ok(42);
    let value = result.unwrap();
    println!("Got: {}", value);
}

fn use_box() {
    let boxed = Box::new(42);
    println!("Boxed: {}", boxed);
}

fn use_arc() {
    let arc = std::sync::Arc::new(42);
    println!("Arc: {}", arc);
}

fn use_string() {
    let s = String::from("hello");
    println!("String: {}", s);
}

fn use_vec() {
    let v = vec![1, 2, 3];
    println!("Vec: {:?}", v);
}

fn use_array_index() {
    let arr = [1, 2, 3, 4, 5];
    let first = arr[0];
    println!("First: {}", first);
}

fn complex_function_with_many_lines() {
    let x = 1;
    let y = 2;
    let z = 3;
    let a = 4;
    let b = 5;
    let c = 6;
    let d = 7;
    let e = 8;
    let f = 9;
    let g = 10;
    let h = 11;
    let i = 12;
    let j = 13;
    let k = 14;
    let l = 15;
    let m = 16;
    let n = 17;
    let o = 18;
    let p = 19;
    let q = 20;
    println!("All: {} {} {} {} {} {} {} {} {} {} {} {} {} {} {} {} {} {} {} {}", x, y, z, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q);
}

fn another_long_function() {
    println!("Line 1");
    println!("Line 2");
    println!("Line 3");
    println!("Line 4");
    println!("Line 5");
    println!("Line 6");
    println!("Line 7");
    println!("Line 8");
    println!("Line 9");
    println!("Line 10");
    println!("Line 11");
    println!("Line 12");
    println!("Line 13");
    println!("Line 14");
    println!("Line 15");
    println!("Line 16");
    println!("Line 17");
    println!("Line 18");
    println!("Line 19");
    println!("Line 20");
    println!("Line 21");
    println!("Line 22");
    println!("Line 23");
    println!("Line 24");
    println!("Line 25");
    println!("Line 26");
    println!("Line 27");
    println!("Line 28");
    println!("Line 29");
    println!("Line 30");
    println!("Line 31");
    println!("Line 32");
    println!("Line 33");
    println!("Line 34");
    println!("Line 35");
    println!("Line 36");
    println!("Line 37");
    println!("Line 38");
    println!("Line 39");
    println!("Line 40");
    println!("Line 41");
    println!("Line 42");
    println!("Line 43");
    println!("Line 44");
    println!("Line 45");
    println!("Line 46");
    println!("Line 47");
    println!("Line 48");
    println!("Line 49");
    println!("Line 50");
}

fn third_long_function() {
    let x = 1;
    println!("{}", x);
    let x = 2;
    println!("{}", x);
    let x = 3;
    println!("{}", x);
    let x = 4;
    println!("{}", x);
    let x = 5;
    println!("{}", x);
    let x = 6;
    println!("{}", x);
    let x = 7;
    println!("{}", x);
    let x = 8;
    println!("{}", x);
    let x = 9;
    println!("{}", x);
    let x = 10;
    println!("{}", x);
    let x = 11;
    println!("{}", x);
    let x = 12;
    println!("{}", x);
    let x = 13;
    println!("{}", x);
    let x = 14;
    println!("{}", x);
    let x = 15;
    println!("{}", x);
    let x = 16;
    println!("{}", x);
    let x = 17;
    println!("{}", x);
    let x = 18;
    println!("{}", x);
    let x = 19;
    println!("{}", x);
    let x = 20;
    println!("{}", x);
    let x = 21;
    println!("{}", x);
    let x = 22;
    println!("{}", x);
    let x = 23;
    println!("{}", x);
    let x = 24;
    println!("{}", x);
    let x = 25;
    println!("{}", x);
    let x = 26;
    println!("{}", x);
    let x = 27;
    println!("{}", x);
    let x = 28;
    println!("{}", x);
    let x = 29;
    println!("{}", x);
    let x = 30;
    println!("{}", x);
    let x = 31;
    println!("{}", x);
    let x = 32;
    println!("{}", x);
    let x = 33;
    println!("{}", x);
    let x = 34;
    println!("{}", x);
    let x = 35;
    println!("{}", x);
    let x = 36;
    println!("{}", x);
    let x = 37;
    println!("{}", x);
    let x = 38;
    println!("{}", x);
    let x = 39;
    println!("{}", x);
    let x = 40;
    println!("{}", x);
    let x = 41;
    println!("{}", x);
    let x = 42;
    println!("{}", x);
    let x = 43;
    println!("{}", x);
    let x = 44;
    println!("{}", x);
    let x = 45;
    println!("{}", x);
    let x = 46;
    println!("{}", x);
    let x = 47;
    println!("{}", x);
    let x = 48;
    println!("{}", x);
    let x = 49;
    println!("{}", x);
    let x = 50;
    println!("{}", x);
}

fn fourth_long_function() {
    eprintln!("Error 1");
    eprintln!("Error 2");
    eprintln!("Error 3");
    eprintln!("Error 4");
    eprintln!("Error 5");
    eprintln!("Error 6");
    eprintln!("Error 7");
    eprintln!("Error 8");
    eprintln!("Error 9");
    eprintln!("Error 10");
    eprintln!("Error 11");
    eprintln!("Error 12");
    eprintln!("Error 13");
    eprintln!("Error 14");
    eprintln!("Error 15");
    eprintln!("Error 16");
    eprintln!("Error 17");
    eprintln!("Error 18");
    eprintln!("Error 19");
    eprintln!("Error 20");
    dbg!(1);
    dbg!(2);
    dbg!(3);
    dbg!(4);
    dbg!(5);
    dbg!(6);
    dbg!(7);
    dbg!(8);
    dbg!(9);
    dbg!(10);
    dbg!(11);
    dbg!(12);
    dbg!(13);
    dbg!(14);
    dbg!(15);
    dbg!(16);
    dbg!(17);
    dbg!(18);
    dbg!(19);
    dbg!(20);
    dbg!(21);
    dbg!(22);
    dbg!(23);
    dbg!(24);
    dbg!(25);
    dbg!(26);
    dbg!(27);
    dbg!(28);
    dbg!(29);
    dbg!(30);
}

fn fifth_function() {
    // TODO: fix this later
    println!("todo 1");
    // FIXME: this is broken
    println!("fixme 1");
    // HACK: temporary workaround
    println!("hack 1");
    // TODO: another todo
    println!("todo 2");
    // FIXME: fix this
    println!("fixme 2");
    // HACK: hack
    println!("hack 2");
    // TODO: more work
    println!("todo 3");
    // FIXME: broken
    println!("fixme 3");
    // HACK: workaround
    println!("hack 3");
    // TODO: pending
    println!("todo 4");
    // FIXME: needs fix
    println!("fixme 4");
    // HACK: temp
    println!("hack 4");
    // TODO: later
    println!("todo 5");
    // FIXME: bug
    println!("fixme 5");
    // HACK: quick fix
    println!("hack 5");
    // TODO: pending
    println!("todo 6");
    // FIXME: issue
    println!("fixme 6");
    // HACK: workaround
    println!("hack 6");
    // TODO: later
    println!("todo 7");
    // FIXME: broken
    println!("fixme 7");
    // HACK: temp
    println!("hack 7");
    // TODO: fix
    println!("todo 8");
    // FIXME: fix
    println!("fixme 8");
    // HACK: hack
    println!("hack 8");
    // TODO: do it
    println!("todo 9");
    // FIXME: fix it
    println!("fixme 9");
    // HACK: do it
    println!("hack 9");
    // TODO: complete
    println!("todo 10");
    // FIXME: complete
    println!("fixme 10");
    // HACK: complete
    println!("hack 10");
}
