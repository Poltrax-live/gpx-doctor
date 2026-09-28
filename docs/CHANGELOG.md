# Changelog

This changelog is based on repository commit history.

## [0.8.0] - 2026-09-28
- Add performance analysis for activity GPX files (`99e2e8f`)
- Add broader performance analysis test coverage (`2e4c2bd`)

## [0.7.0] - 2026-09-18
- Parse GPX 1.0 namespaced files (`d3d060f`)

## [0.6.2] - 2026-09-02
- Keep standalone waypoints out of `Result#points` (`34ec236`)

## [0.6.1] - 2026-08-31
- Set `cumulative_distance` on `label_interval` inserted points (`d826dec`)
- Coerce `label_interval` target to float (`f6ad97a`)

## [0.6.0] - 2026-08-31
- Add `label_interval` option to insert labelled points at distance marks (`0e24e64`)
- Fix target advancement in `PointLabeler` and add regression test (`b18ec1f`)
- Run `label_interval` after cumulative distance and reuse precomputed distances (`d92b360`)
- Require cumulative distance for all points reused in `PointLabeler` (`b645fc9`)

## [0.5.0] - 2026-08-16
- Add `full_poi_data` parser param returning POIs with start/finish/segments (`fe6392f`)
- Document `full_poi_data` and parse params in README (`9f1318c`)

## [0.4.0] - 2026-07-07
- Add unit system configuration and converters (`3b013c7`)
- Add comprehensive RSpec tests for imperial units (`56b4c68`)
- Convert cumulative distance to kilometers (`23a32f3`)
- Add cumulative distance parser feature and documentation (`6f5013d`, `920caa7`)

## [0.3.0 and earlier] - 2026-03-31 to 2026-06-29
- Create GPX Doctor gem with parser, models, configuration, and specs (`c7371c7`)
- Add parser fixture tests and cleanup (`c5ca2f9`, `882c397`, `012e42c`, `2ece12f`)
- Add elevation enhancement with Open Elevation API integration (`bc50db6`, `e92e2a3`)
- Add per-point statistics enhancer and parse-level statistics toggle (`5de4f8f`, `6af61f5`)
- Add `max_distance` and `max_points` parse params with segment splitting updates (`559e214`, `f777503`, `6917616`)
- Extract shared distance calculations (`7fe24be`, `54e3556`)
- Add GPX builder and end-to-end parse/transform/build scenarios (`97df6f2`, `d4a15a0`, `ebf55be`)
- Guard and gate elevation enhancement execution (`8ee106a`, `1dbae69`)
- Add GPX validation against invalid and malicious files (`a703462`)
- Add GeoJSON builder with RFC 7946 compliance and docs (`3787a47`, `eed2f66`, `d61fbb9`)
- Add GPX builder usage documentation (`649e100`, `8cae302`)
