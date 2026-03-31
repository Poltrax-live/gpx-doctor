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

## License

MIT
