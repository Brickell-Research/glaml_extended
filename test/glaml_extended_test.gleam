import glaml_extended
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn parse_string_test() {
  let assert Ok([a, b]) =
    glaml_extended.parse_string(
      "x: 2048\ny: 4096\nz: 1024\n---\nx: 0\ny: 0\nz: 0",
    )

  should.equal(
    a,
    glaml_extended.Document(
      glaml_extended.NodeMap([
        #(glaml_extended.NodeStr("x"), glaml_extended.NodeInt(2048)),
        #(glaml_extended.NodeStr("y"), glaml_extended.NodeInt(4096)),
        #(glaml_extended.NodeStr("z"), glaml_extended.NodeInt(1024)),
      ]),
    ),
  )

  should.equal(
    b,
    glaml_extended.Document(
      glaml_extended.NodeMap([
        #(glaml_extended.NodeStr("x"), glaml_extended.NodeInt(0)),
        #(glaml_extended.NodeStr("y"), glaml_extended.NodeInt(0)),
        #(glaml_extended.NodeStr("z"), glaml_extended.NodeInt(0)),
      ]),
    ),
  )
}

pub fn parse_file_test() {
  let assert Ok(docs) = glaml_extended.parse_file("./test/multi_document.yaml")

  should.equal(docs, [
    glaml_extended.Document(
      glaml_extended.NodeMap([
        #(glaml_extended.NodeStr("doc"), glaml_extended.NodeInt(1)),
      ]),
    ),
    glaml_extended.Document(
      glaml_extended.NodeMap([
        #(glaml_extended.NodeStr("doc"), glaml_extended.NodeInt(2)),
      ]),
    ),
    glaml_extended.Document(
      glaml_extended.NodeMap([
        #(glaml_extended.NodeStr("doc"), glaml_extended.NodeInt(3)),
      ]),
    ),
  ])
}

pub fn selector_test() {
  let assert Ok([doc]) = glaml_extended.parse_file("./test/test.yaml")

  glaml_extended.document_root(doc)
  |> glaml_extended.select(
    glaml_extended.Selector([
      glaml_extended.SelectSeq(0),
      glaml_extended.SelectMap(glaml_extended.NodeStr("item_count")),
    ]),
  )
  |> should.equal(Ok(glaml_extended.NodeInt(7)))
}

pub fn sugar_test() {
  let assert Ok([doc]) = glaml_extended.parse_file("./test/test.yaml")

  glaml_extended.select_sugar(
    glaml_extended.document_root(doc),
    "#0.display name",
  )
  |> should.equal(Ok(glaml_extended.NodeStr("snow leopard")))
}

pub fn unicode_test() {
  let assert Ok([doc]) = glaml_extended.parse_file("./test/unicode_test.yaml")

  glaml_extended.select_sugar(
    glaml_extended.document_root(doc),
    "records.#0.title",
  )
  |> should.equal(Ok(glaml_extended.NodeStr("健康サポート")))
}

pub fn error_test() {
  let node =
    glaml_extended.NodeSeq([
      glaml_extended.NodeMap([
        #(glaml_extended.NodeStr("valid"), glaml_extended.NodeNil),
      ]),
    ])

  glaml_extended.select(
    from: node,
    selector: glaml_extended.Selector([
      glaml_extended.SelectSeq(0),
      glaml_extended.SelectMap(glaml_extended.NodeStr("invalid")),
    ]),
  )
  |> should.equal(Error(glaml_extended.NodeNotFound(1)))

  glaml_extended.parse_selector("#invalid index")
  |> should.equal(Error(glaml_extended.SelectorParseError))
}

pub fn duplicate_key_test() {
  let assert Ok(docs) = glaml_extended.parse_file("./test/duplicate_keys.yaml")

  should.equal(docs, [
    glaml_extended.Document(
      glaml_extended.NodeMap([
        #(glaml_extended.NodeStr("doc"), glaml_extended.NodeInt(1)),
        #(glaml_extended.NodeStr("doc"), glaml_extended.NodeInt(2)),
      ]),
    ),
    glaml_extended.Document(
      glaml_extended.NodeMap([
        #(
          glaml_extended.NodeStr("doc"),
          glaml_extended.NodeMap([
            #(
              glaml_extended.NodeStr("inputs"),
              glaml_extended.NodeMap([
                #(glaml_extended.NodeStr("foo"), glaml_extended.NodeInt(1)),
                #(glaml_extended.NodeStr("foo"), glaml_extended.NodeInt(2)),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
}
