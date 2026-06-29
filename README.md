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
  enhance_elevation:  true           # fetch missing elevations from the configured elevation server
})
```

Processing is applied in the following order:

1. `max_distance` — segment splitting (interpolates intermediate points)
2. `max_points` — point reduction
3. `segment_statistics` — per-point statistics (distance, bearing, elevation change)
4. `enhance_elevation` — elevation lookup via the elevation server

`enhance_elevation: true` requires the elevation server to be configured (see **Configuration** above). It only fills in points that have no elevation value; existing elevations are left unchanged.

## Accessing data

```ruby
result.points    # => [#<Waypoint lat=…, lon=…, ele=…>, …]  (all geographic points)
result.waypoints # => [#<Waypoint …>]  (top-level <wpt> elements only)
result.routes    # => [#<Route …>]
result.tracks    # => [#<Track …>]
result.metadata  # => #<Metadata …>  (or nil)
```

`result.points` is a flat array containing **all** geographic points from:
- Top-level `<wpt>` elements
- `<rtept>` elements inside each `<rte>`
- `<trkpt>` elements inside each `<trkseg>` inside each `<trk>`

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

# Optional: specify a custom creator attribute
xml_string = GpxDoctor::Builder.build(result, creator: 'My Application')
```

### Build to a file

```ruby
GpxDoctor::Builder.build_file(result, 'path/to/output.gpx')
# Writes the GPX XML to the file and returns the XML string
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
