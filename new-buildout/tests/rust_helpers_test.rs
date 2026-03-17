#[test]
fn reads_value() {
    let parsed = Some("value").unwrap();
    assert_eq!(parsed, "value");
}
