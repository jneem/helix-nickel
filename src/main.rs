use serde_json::{Map, Value};

// Problems with rust-analyzer json schemas:
// - strip out "default", which is non-standard right now
// - strip out "rust-analyzer" prefix
// - replace field paths with nested objects
// - add some global stuff
fn munge_rust_analyzer_schema(schema: Value) -> Value {
    let Value::Object(obj) = schema else {
        panic!("not an object");
    };
    let mut ret = json_schema_object();

    for (name, val) in obj {
        add_field(&mut ret, &name, val);
    }

    ret
}

fn json_schema_object() -> Value {
    Value::Object(
        [
            ("type".to_owned(), "object".into()),
            ("properties".to_owned(), Value::Object(Map::new())),
            ("additionalProperties".to_owned(), false.into()),
        ]
        .into_iter()
        .collect(),
    )
}

fn add_field(schema: &mut Value, path: &str, val: Value) {
    let mut parts = path.split('.');
    let first = parts.next();

    assert_eq!(first, Some("rust-analyzer"));

    fn add_rec<'a>(schema: &mut Value, mut path: impl Iterator<Item = &'a str>, val: Value) {
        if let Some(field) = path.next() {
            let schema = schema.as_object_mut().expect("subfield not an object");
            let sub_schema = schema
                .get_mut("properties")
                .unwrap()
                .as_object_mut()
                .unwrap()
                .entry(field)
                .or_insert_with(json_schema_object);
            add_rec(sub_schema, path, val);
        } else {
            *schema = val;
        }
    }

    add_rec(schema, parts, val);
}

fn main() -> anyhow::Result<()> {
    let input: Value = serde_json::from_reader(std::io::stdin())?;
    let mut output = munge_rust_analyzer_schema(input);

    output.as_object_mut().unwrap().insert(
        "$schema".to_owned(),
        "https://json-schema.org/draft-07/schema".into(),
    );

    serde_json::to_writer_pretty(std::io::stdout(), &output)?;

    Ok(())
}
