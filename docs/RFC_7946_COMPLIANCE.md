# RFC 7946 GeoJSON Specification Compliance

This document describes how `GpxDoctor::GeoJsonBuilder` complies with RFC 7946 (The GeoJSON Format).

## Compliant Features

### 1. Coordinate Reference System (Section 4)
- **Requirement**: GeoJSON uses WGS84 geographic coordinate reference system
- **Compliance**: All coordinates from GPX files (which use WGS84) are passed through unchanged
- **Implementation**: No coordinate transformation is performed

### 2. Coordinate Order (Section 3.1.1)
- **Requirement**: Position is [longitude, latitude] with optional elevation as third element
- **Compliance**: ✅ Coordinates are always `[lon, lat]` or `[lon, lat, elevation]`
- **Implementation**: See `coordinate(point)` method in `geojson_builder.rb`

### 3. FeatureCollection Structure (Section 3.3)
- **Requirement**: Must have `"type": "FeatureCollection"` and `"features"` array
- **Compliance**: ✅ Output always has both required members
- **Implementation**: See `build()` method

### 4. Feature Structure (Section 3.2)
- **Requirement**: Must have `"type": "Feature"`, `"geometry"`, and `"properties"` members
- **Compliance**: ✅ All features include all three members
- **Implementation**: See `point_feature()`, `route_features()`, and `track_features()` methods

### 5. Properties Member (Section 3.2)
- **Requirement**: Properties member value MAY be null or an object
- **Compliance**: ✅ Empty properties are represented as `null`, non-empty as objects
- **Implementation**: `props.empty? ? nil : props` pattern used throughout

### 6. Geometry Types

#### Point (Section 3.1.2)
- **Requirement**: Position is a single position array
- **Compliance**: ✅ Waypoints become Point features
- **Implementation**: GPX `<wpt>` elements → GeoJSON Point

#### LineString (Section 3.1.4)
- **Requirement**: Positions array must have two or more positions
- **Compliance**: ✅ Routes with fewer than 2 points are filtered out
- **Implementation**: `next if coords.length < 2` in `route_features()`

#### MultiLineString (Section 3.1.5)
- **Requirement**: Array of LineString coordinate arrays; each must have 2+ positions
- **Compliance**: ✅ Invalid segments are filtered; tracks with no valid segments are excluded
- **Implementation**: Segment validation in `track_features()`

## Mapping from GPX to GeoJSON

| GPX Element | GeoJSON Type | Notes |
|-------------|--------------|-------|
| `<wpt>` | Point | One feature per waypoint |
| `<rte>` | LineString | One feature per route; route points become coordinates |
| `<trk>` with `<trkseg>` | MultiLineString | One feature per track; each segment becomes a LineString |

## Properties Mapping

### Waypoint Properties
- `name` → `name`
- `desc` → `desc`
- `sym` → `sym`
- `type` → `type`
- `time` → `time` (as ISO 8601 string)

### Route/Track Properties
- `name` → `name`
- `desc` → `desc`
- `type` → `type`
- `number` → `number`

## Validation and Filtering

The builder validates geometries according to RFC 7946:

1. **LineString validation**: Routes must have at least 2 coordinate positions
2. **MultiLineString validation**: Track segments must each have at least 2 positions
3. **Empty geometry handling**: Features with invalid geometries are excluded from output

## Testing

See `spec/gpx_doctor/geojson_builder_spec.rb` for comprehensive tests including:
- RFC 7946 compliance test suite
- Coordinate order validation
- Geometry validation (minimum positions)
- Properties null/object handling
- Edge case handling (empty routes, single-point segments, etc.)

## References

- RFC 7946: https://www.rfc-editor.org/rfc/rfc7946
- GPX 1.1 Schema: https://www.topografix.com/GPX/1/1/
