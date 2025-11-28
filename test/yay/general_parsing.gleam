import gleeunit/should
import yay

pub fn parse_string_test() {
  let assert Ok([a, b]) =
    yay.parse_string("x: 2048\ny: 4096\nz: 1024\n---\nx: 0\ny: 0\nz: 0")

  should.equal(
    a,
    yay.Document(
      yay.NodeMap([
        #(yay.NodeStr("x"), yay.NodeInt(2048)),
        #(yay.NodeStr("y"), yay.NodeInt(4096)),
        #(yay.NodeStr("z"), yay.NodeInt(1024)),
      ]),
    ),
  )

  should.equal(
    b,
    yay.Document(
      yay.NodeMap([
        #(yay.NodeStr("x"), yay.NodeInt(0)),
        #(yay.NodeStr("y"), yay.NodeInt(0)),
        #(yay.NodeStr("z"), yay.NodeInt(0)),
      ]),
    ),
  )
}

pub fn parse_file_test() {
  let assert Ok(docs) =
    yay.parse_file("./test/yay/artifacts/multi_document.yaml")

  should.equal(docs, [
    yay.Document(yay.NodeMap([#(yay.NodeStr("doc"), yay.NodeInt(1))])),
    yay.Document(yay.NodeMap([#(yay.NodeStr("doc"), yay.NodeInt(2))])),
    yay.Document(yay.NodeMap([#(yay.NodeStr("doc"), yay.NodeInt(3))])),
  ])
}

pub fn selector_test() {
  let assert Ok([doc]) = yay.parse_file("./test/yay/artifacts/test.yaml")

  yay.document_root(doc)
  |> yay.select(
    yay.Selector([yay.SelectSeq(0), yay.SelectMap(yay.NodeStr("item_count"))]),
  )
  |> should.equal(Ok(yay.NodeInt(7)))
}

pub fn sugar_test() {
  let assert Ok([doc]) = yay.parse_file("./test/yay/artifacts/test.yaml")

  yay.select_sugar(yay.document_root(doc), "#0.display name")
  |> should.equal(Ok(yay.NodeStr("snow leopard")))
}

pub fn unicode_test() {
  let assert Ok([doc]) =
    yay.parse_file("./test/yay/artifacts/unicode_test.yaml")

  yay.select_sugar(yay.document_root(doc), "records.#0.title")
  |> should.equal(Ok(yay.NodeStr("健康サポート")))
}

pub fn error_test() {
  let node = yay.NodeSeq([yay.NodeMap([#(yay.NodeStr("valid"), yay.NodeNil)])])

  yay.select(
    from: node,
    selector: yay.Selector([
      yay.SelectSeq(0),
      yay.SelectMap(yay.NodeStr("invalid")),
    ]),
  )
  |> should.equal(Error(yay.NodeNotFound(1)))

  yay.parse_selector("#invalid index")
  |> should.equal(Error(yay.SelectorParseError))
}

pub fn duplicate_key_test() {
  let assert Ok(docs) =
    yay.parse_file("./test/yay/artifacts/duplicate_keys.yaml")

  should.equal(docs, [
    yay.Document(
      yay.NodeMap([
        #(yay.NodeStr("doc"), yay.NodeInt(1)),
        #(yay.NodeStr("doc"), yay.NodeInt(2)),
      ]),
    ),
    yay.Document(
      yay.NodeMap([
        #(
          yay.NodeStr("doc"),
          yay.NodeMap([
            #(
              yay.NodeStr("inputs"),
              yay.NodeMap([
                #(yay.NodeStr("foo"), yay.NodeInt(1)),
                #(yay.NodeStr("foo"), yay.NodeInt(2)),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
}
