use std::borrow::Cow;
use std::io::ErrorKind;
use std::sync::Arc;

use fig_os_shim::Context;
use tracing::{
    debug,
    error,
};
use wry::http::header::CONTENT_TYPE;
use wry::http::{
    Request,
    Response,
    StatusCode,
};

use crate::webview::WindowId;

fn res(status: StatusCode, content_type: &'static str, body: Cow<'static, [u8]>) -> Response<Cow<'static, [u8]>> {
    Response::builder()
        .status(status)
        .header(CONTENT_TYPE, content_type)
        .body(body)
        .unwrap()
}

fn res_404() -> Response<Cow<'static, [u8]>> {
    res(StatusCode::NOT_FOUND, "text/plain", b"Not Found".as_ref().into())
}

/// Serves completion specs from the local specs dir, there is no remote CDN.
///
/// The dir holds the `build/` output of the `@withfig/autocomplete` package
/// (`index.json` plus one `.js` file or folder per spec), see `scripts/update-specs.sh`.
///
/// handle `spec://localhost/index.json` and `spec://localhost/{spec}.js`
pub async fn handle(
    _ctx: Arc<Context>,
    request: Request<Vec<u8>>,
    _: WindowId,
) -> anyhow::Result<Response<Cow<'static, [u8]>>> {
    let specs_dir = match fig_util::directories::autocomplete_specs_dir().and_then(|dir| Ok(dir.canonicalize()?)) {
        Ok(dir) => dir,
        Err(err) => {
            error!(%err, "specs dir is missing, run scripts/update-specs.sh");
            return Ok(res_404());
        },
    };

    let uri_path = percent_encoding::percent_decode_str(request.uri().path()).decode_utf8()?;
    let relative = uri_path.trim_start_matches('/');

    let path = match specs_dir.join(relative).canonicalize() {
        Ok(path) => path,
        Err(err) if err.kind() == ErrorKind::NotFound => {
            debug!(%uri_path, "spec not found");
            return Ok(res_404());
        },
        Err(err) => return Err(err.into()),
    };

    // dont allow escaping the specs dir
    if !path.starts_with(&specs_dir) || !path.is_file() {
        return Ok(res_404());
    }

    let content_type = match path.extension().and_then(|ext| ext.to_str()) {
        Some("json") => "application/json",
        _ => "application/javascript",
    };

    Ok(res(StatusCode::OK, content_type, tokio::fs::read(&path).await?.into()))
}
