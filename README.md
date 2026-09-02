# GPX Doctor

A Ruby gem for parsing and manipulating GPX 1.1 routes.

## Installation

Add to your Gemfile:

```ruby
gem "gpx_doctor"
```

Or install directly:

```bash
gem install gpx_doctor
```

## Configuration

```ruby
GpxDoctor.configure do |config|
  config.elevation_server          = true
  config.elevation_server_url      = "https://elevation.example.com"
  config.elevation_server_user     = "user"
  config.elevation_server_password = "secret"
  config.unit_system               = :imperial  # or :metric (default)
end

GpxDoctor.configuration.elevation_server_url # => "https://elevation.example.com"
GpxDoctor.reset_configuration!               # resets to defaults
```

| Option | Type | Default | Description |
|---|---|---|---|
| `elevation_server` | Boolean | `false` | Whether to use an elevation server |
| `elevation_server_url` | String | `nil` | URL of the elevation server |
| `elevation_server_user` | String | `nil` | Username for the elevation server |
| `elevation_server_password` | String | `nil` | Password for the elevation server |
| `unit_system` | Symbol | `:metric` | Unit system (`:metric` or `:imperial`) for distance and elevation values |

### Unit System

The `unit_system` configuration affects the following fields:

- **`:metric` (default)**:
  - `distance_to_next` and `elevation_change` are in **meters**
  - `cumulative_distance` is in **kilometers**
- **`:imperial`**:
  - `distance_to_next` and `elevation_change` are in **feet**
  - `cumulative_distance` is in **miles**

```ruby
# Use imperial units
GpxDoctor.configure do |config|
  config.unit_system = :imperial
end

result = GpxDoctor::Parser.parse("path/to/file.gpx", params: { 
  segment_statistics: true, 
  cumulative_distance: true 
})

# distance_to_next and elevation_change will be in feet
# cumulative_distance will be in miles
```

## Parsing

### From a file

```ruby
result = GpxDoctor::Parser.parse("path/to/file.gpx")
```

### From a string

```ruby
result = GpxDoctor::Parser.parse_string(xml_string)
```

### Parsing with processing parameters

Both `parse` and `parse_string` accept an optional `params:` hash to enable post-processing:

```ruby
result = GpxDoctor::Parser.parse("path/to/file.gpx", params: {
  max_distance:       200,           # insert interpolated points so no two consecutive points exceed this distance (metres)
  max_points:         500,           # reduce each segment to at most this many points
  segment_statistics: true,          # compute distance_to_next, elevation_change, direction for each point
  cumulative_distance: true,         # add cumulative distance from start of each segment/route
  label_interval:     1.0,           # insert an interpolated, labelled point at every interval mark (kilometres or miles based on unit_system)
  enhance_elevation:  true,          # fetch missing elevations from the configured elevation server
  full_poi_data:      true           # populate result.pois with start/finish boundary data for the whole GPX and each track segment
})
```

Processing is applied in the following order:

1. `max_distance` — segment splitting (interpolates intermediate points)
2. `max_points` — point reduction
3. `segment_statistics` — per-point statistics (distance, bearing, elevation change)
4. `cumulative_distance` — cumulative distance from the start of each segment/route
5. `label_interval` — labelled point insertion
6. `enhance_elevation` — elevation lookup via the elevation server
7. `full_poi_data` — POI boundary extraction (start, finish, and per-segment boundaries)

`enhance_elevation: true` requires the elevation server to be configured (see **Configuration** above). It only fills in points that have no elevation value; existing elevations are left unchanged.

`cumulative_distance: true` adds a `cumulative_distance` field to each point, representing the cumulative distance in kilometers from the start of its segment or route. For tracks with multiple segments, each segment's cumulative distance starts at 0.0 (gaps between segments are not included in the calculation).

`label_interval: 1.0` walks each route/segment and inserts an interpolated point at every multiple of the given interval (measured as cumulative distance from the start, in kilometres for `:metric` or miles for `:imperial` — see **Unit System** above), setting the new point's `label` field to that distance (e.g. `1.0` for the point at the 1.0 km/mi mark). A mark falling on an existing point (within a small tolerance) is skipped rather than duplicated. `label_interval` runs after `cumulative_distance`, reusing its `cumulative_distance` values instead of recalculating them when `cumulative_distance: true` is also given. **Because `label_interval` is applied after `max_points`, the resulting number of points may exceed `max_points`.**

`full_poi_data: true` populates `result.pois` with the first and last geographic point of the entire GPX (across all routes and track segments), plus optional per-segment boundary data. Distances within each segment start at 0.0 and reflect that segment's length only. The `ele` key is omitted for points that have no elevation value. The global `finish` distance is the sum of all individual collection lengths. See **`result.pois`** below for the output shape.

## Accessing data

```ruby
result.points     # => [#<Waypoint lat=…, lon=…, ele=…>, …]  (the path)
result.all_points # => [#<Waypoint …>, …]  (the path plus standalone waypoints)
result.waypoints  # => [#<Waypoint …>]  (top-level <wpt> elements only)
result.routes     # => [#<Route …>]
result.tracks     # => [#<Track …>]
result.metadata   # => #<Metadata …>  (or nil)
result.pois       # => Hash (only when parsed with full_poi_data: true, otherwise nil)
```

`result.points` is a flat array describing **the path**, in order:
- `<rtept>` elements inside each `<rte>`
- `<trkpt>` elements inside each `<trkseg>` inside each `<trk>`

Top-level `<wpt>` elements are **not** included. They are points of interest that may
sit anywhere on — or off — the path, and exporters list them in file order rather than
path order, so treating them as path points draws straight lines back and forth across
the map. Read them from `result.waypoints`, or use `result.all_points` (standalone
waypoints first, then the path) when you genuinely want every geographic point in the
file. All processing params (`max_points`, `cumulative_distance`, `label_interval`,
`segment_statistics`, `full_poi_data`) operate on the path only; `enhance_elevation` is
the exception and fills in elevations for standalone waypoints too.

### `result.pois`

When parsed with `full_poi_data: true`, `result.pois` contains boundary data for the entire GPX and each track segment:

```ruby
result = GpxDoctor::Parser.parse("route.gpx", params: { full_poi_data: true })
result.pois
# =>
# {
#   start:  { lon: 16.38, lat: 48.23, ele: 170.0, distance: 0.0 },
#   finish: { lon: 16.39, lat: 48.24, ele: 175.0, distance: 1.42 },
#   segments: [
#     {
#       start:  { lon: 16.38, lat: 48.23, ele: 170.0, distance: 0.0 },
#       finish: { lon: 16.39, lat: 48.24, ele: 175.0, distance: 1.42 }
#     }
#   ]
# }
```

- **`start`** / **`finish`** — first and last geographic point across all routes and track segments, each with `lon`, `lat`, `distance` (and `ele` when present). `start` always has `distance: 0.0`; `finish` distance is the sum of all individual route/segment lengths.
- **`segments`** — present only when the GPX contains track segments. Each entry is `{start:, finish:}` for one `<trkseg>`, with distances measured from the beginning of that segment (`start` is always `distance: 0.0`).
- The `ele` key is omitted for points that have no elevation value.
- Distance values respect the configured `unit_system` (kilometres for `:metric`, miles for `:imperial`).

## Building GPX files

The `GpxDoctor::Builder` class generates GPX 1.1 XML from a `Result` object (the same structure returned by the parser).

### Build to a string

```ruby
result = GpxDoctor::Parser::Result.new(
  waypoints: [],
  routes: [],
  tracks: [],
  metadata: nil
)

xml_string = GpxDoctor::Builder.build(result)
# => "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<gpx version=\"1.1\"..."

# Optional: specify a custom creator attribute (identifies the software that created the GPX file)
xml_string = GpxDoctor::Builder.build(result, creator: 'My Application')
```

### Build to a file

```ruby
GpxDoctor::Builder.build_file(result, 'path/to/output.gpx')
# Writes the GPX XML to the file and returns the XML string

# Optional: specify a custom creator attribute
GpxDoctor::Builder.build_file(result, 'path/to/output.gpx', creator: 'My Application')
```

### Input structure

The builder expects a `GpxDoctor::Parser::Result` object with the following fields:

- **`waypoints`** — Array of `GpxDoctor::Waypoint` objects (top-level waypoints)
- **`routes`** — Array of `GpxDoctor::Route` objects
- **`tracks`** — Array of `GpxDoctor::Track` objects
- **`metadata`** — `GpxDoctor::Metadata` object (optional)

All model classes are simple Ruby objects with attributes matching the GPX 1.1 specification (see **Model field reference** below).

### Example: Creating a GPX file from scratch

```ruby
require 'gpx_doctor'

# Create waypoints
waypoint = GpxDoctor::Waypoint.new(
  lat: 48.2093723,
  lon: 16.356099,
  ele: 160.0,
  name: 'Vienna',
  desc: 'Capital of Austria'
)

# Create a route with points
route_point_1 = GpxDoctor::Waypoint.new(lat: 48.21, lon: 16.36, ele: 155.0)
route_point_2 = GpxDoctor::Waypoint.new(lat: 48.22, lon: 16.37, ele: 162.0)

route = GpxDoctor::Route.new(
  name: 'City Tour',
  desc: 'A route through the city',
  points: [route_point_1, route_point_2]
)

# Create a track with segments
track_point_1 = GpxDoctor::Waypoint.new(lat: 48.23, lon: 16.38, ele: 170.0)
track_point_2 = GpxDoctor::Waypoint.new(lat: 48.24, lon: 16.39, ele: 175.0)

segment = GpxDoctor::TrackSegment.new(points: [track_point_1, track_point_2])
track = GpxDoctor::Track.new(
  name: 'Morning Run',
  desc: 'My morning jog',
  segments: [segment]
)

# Create metadata (optional)
metadata = GpxDoctor::Metadata.new(
  name: 'My GPX File',
  desc: 'A custom GPX file',
  time: Time.now
)

# Build the result object
result = GpxDoctor::Parser::Result.new(
  waypoints: [waypoint],
  routes: [route],
  tracks: [track],
  metadata: metadata
)

# Generate GPX XML
xml_string = GpxDoctor::Builder.build(result, creator: 'My Application')

# Or write directly to a file
GpxDoctor::Builder.build_file(result, 'my_route.gpx', creator: 'My Application')
```

### Round-trip workflow

You can parse an existing GPX file, modify it, and build it back:

```ruby
# Parse existing file
result = GpxDoctor::Parser.parse('input.gpx')

# Modify data
result.routes.first.name = 'Updated Route Name'
result.waypoints << GpxDoctor::Waypoint.new(lat: 48.5, lon: 16.5, name: 'New Point')

# Build back to GPX
GpxDoctor::Builder.build_file(result, 'output.gpx')
```

## Model field reference

### `Waypoint`

| Field | Type | Notes |
|---|---|---|
| `lat` | Float | Required |
| `lon` | Float | Required |
| `ele` | Float | Elevation in metres |
| `time` | Time | |
| `magvar` | Float | Magnetic variation |
| `geoidheight` | Float | |
| `name` | String | |
| `cmt` | String | Comment |
| `desc` | String | Description |
| `src` | String | Source |
| `links` | Array<Link> | |
| `sym` | String | Symbol |
| `type` | String | |
| `fix` | String | `none`, `2d`, `3d`, `dgps`, `pps` |
| `sat` | Integer | Number of satellites |
| `hdop` | Float | |
| `vdop` | Float | |
| `pdop` | Float | |
| `ageofdgpsdata` | Float | |
| `dgpsid` | Integer | 0–1023 |
| `distance_to_next` | Float | Distance to next point (metres or feet based on `unit_system`) — set by `segment_statistics: true` |
| `elevation_change` | Float | Elevation change to next point (metres or feet based on `unit_system`) — set by `segment_statistics: true` |
| `direction` | Float | Bearing to next point (0–360°) — set by `segment_statistics: true` |
| `cumulative_distance` | Float | Cumulative distance from segment/route start (kilometres or miles based on `unit_system`) — set by `cumulative_distance: true`; also set (to the same value as `label`) for points inserted by `label_interval` |
| `label` | Float | Cumulative distance mark for a point inserted by `label_interval` (kilometres or miles based on `unit_system`); `nil` for points not created for labelling — set by `label_interval` |

`Waypoint#to_h` returns a hash of all non-nil fields.

### `Metadata`

| Field | Type |
|---|---|
| `name` | String |
| `desc` | String |
| `author` | Person |
| `copyright` | Copyright |
| `links` | Array<Link> |
| `time` | Time |
| `keywords` | String |
| `bounds` | Bounds |

### `Route`

| Field | Type |
|---|---|
| `name` | String |
| `cmt` | String |
| `desc` | String |
| `src` | String |
| `links` | Array<Link> |
| `number` | Integer |
| `type` | String |
| `points` | Array<Waypoint> |

### `Track`

| Field | Type |
|---|---|
| `name` | String |
| `cmt` | String |
| `desc` | String |
| `src` | String |
| `links` | Array<Link> |
| `number` | Integer |
| `type` | String |
| `segments` | Array<TrackSegment> |
| `points` | Array<Waypoint> (all points across all segments) |

### `TrackSegment`

| Field | Type |
|---|---|
| `points` | Array<Waypoint> |

### `Person`

| Field | Type |
|---|---|
| `name` | String |
| `email` | Email |
| `link` | Link |

### `Copyright`

| Field | Type |
|---|---|
| `author` | String |
| `year` | String |
| `license` | String |

### `Link`

| Field | Type |
|---|---|
| `href` | String |
| `text` | String |
| `type` | String |

### `Email`

| Field | Type |
|---|---|
| `id` | String |
| `domain` | String |

`Email#to_s` returns `"id@domain"`.

### `Bounds`

| Field | Type |
|---|---|
| `minlat` | Float |
| `minlon` | Float |
| `maxlat` | Float |
| `maxlon` | Float |

## Development

### Building the gem

```bash
gem build gpx_doctor.gemspec
```

This produces a file like `gpx_doctor-0.1.0.gem` in the current directory.

### Running tests

```bash
bundle install
bundle exec rspec
```

### Publishing to RubyGems

1. **Create an account** at <https://rubygems.org> if you don't have one.

2. **Set up credentials** (one-time):

   ```bash
   gem signin
   ```

   This stores your API key in `~/.gem/credentials`.

3. **Build and push**:

   ```bash
   gem build gpx_doctor.gemspec
   gem push gpx_doctor-0.1.0.gem
   ```

4. **Verify** the release at `https://rubygems.org/gems/gpx_doctor`.

> **Tip:** Bump `GpxDoctor::VERSION` in `lib/gpx_doctor/version.rb` before each release and tag the commit:
>
> ```bash
> git tag -a v0.1.0 -m "Release 0.1.0"
> git push origin v0.1.0
> ```

## License

MIT
