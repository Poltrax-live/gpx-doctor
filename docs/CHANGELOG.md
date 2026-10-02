# Changelog

This changelog is based on repository commit history.

## [0.9.0] - 2026-10-02
- Add `GpxDoctor::Similarity` comparing a reference GPX path with another file, coordinate collection or GeoJSON document, regardless of the order the compared points come in

## [0.8.0] - 2026-09-28
- Add performance analysis for activity GPX files with broader test coverage (`99e2e8f`, `2e4c2bd`)

## [0.7.0] - 2026-09-18
- Parse GPX 1.0 namespaced files (`d3d060f`)

## [0.6.2] - 2026-09-02
- Keep standalone waypoints out of `Result#points` (`34ec236`)

## [0.6.1] - 2026-08-31
- Improve `label_interval` point generation by setting `cumulative_distance` and coercing target values (`d826dec`, `f6ad97a`)

## [0.6.0] - 2026-08-31
- Add `label_interval` support with distance reuse, target advancement fixes, and cumulative-distance safeguards (`0e24e64`, `b18ec1f`, `d92b360`, `b645fc9`)

## [0.5.0] - 2026-08-16
- Add `full_poi_data` parser param returning POIs with start/finish/segments and document parse params (`fe6392f`, `9f1318c`)

## [0.4.0] - 2026-07-07
- Add unit system configuration/converters with comprehensive imperial-unit test coverage (`3b013c7`, `56b4c68`)
- Add cumulative-distance parser support in kilometers with documentation (`6f5013d`, `23a32f3`, `920caa7`)

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
