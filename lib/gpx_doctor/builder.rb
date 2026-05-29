# frozen_string_literal: true

require 'nokogiri'

module GpxDoctor
  class Builder
    GPX_NS          = 'http://www.topografix.com/GPX/1/1'
    XSI_NS          = 'http://www.w3.org/2001/XMLSchema-instance'
    SCHEMA_LOCATION = "#{GPX_NS} http://www.topografix.com/GPX/1/1/gpx.xsd"

    class << self
      def build(result, creator: 'GPX Doctor')
        new(result, creator: creator).build
      end

      def build_file(result, file_path, creator: 'GPX Doctor')
        xml = build(result, creator: creator)
        File.write(file_path, xml)
        xml
      end
    end

    def initialize(result, creator: 'GPX Doctor')
      @result  = result
      @creator = creator
    end

    def build
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.gpx(
          'version'              => '1.1',
          'creator'              => @creator,
          'xmlns'                => GPX_NS,
          'xmlns:xsi'            => XSI_NS,
          'xsi:schemaLocation'   => SCHEMA_LOCATION
        ) do
          build_metadata(xml, @result.metadata) if @result.metadata
          @result.waypoints.each { |wpt| build_waypoint(xml, wpt, tag: 'wpt') }
          @result.routes.each    { |rte| build_route(xml, rte) }
          @result.tracks.each    { |trk| build_track(xml, trk) }
        end
      end
      builder.to_xml
    end

    private

    def build_metadata(xml, metadata)
      xml.metadata do
        xml.name     metadata.name     if metadata.name
        xml.desc     metadata.desc     if metadata.desc
        build_person(xml, metadata.author)         if metadata.author
        build_copyright(xml, metadata.copyright)   if metadata.copyright
        metadata.links.each { |link| build_link(xml, link) }
        xml.time     metadata.time.iso8601  if metadata.time
        xml.keywords metadata.keywords      if metadata.keywords
        build_bounds(xml, metadata.bounds)  if metadata.bounds
      end
    end

    def build_person(xml, person)
      xml.author do
        xml.name person.name if person.name
        build_email(xml, person.email) if person.email
        build_link(xml, person.link)   if person.link
      end
    end

    def build_email(xml, email)
      xml.email('id' => email.id, 'domain' => email.domain)
    end

    def build_copyright(xml, copyright)
      xml.copyright('author' => copyright.author) do
        xml.year    copyright.year    if copyright.year
        xml.license copyright.license if copyright.license
      end
    end

    def build_link(xml, link)
      xml.link('href' => link.href) do
        if link.text
          node = Nokogiri::XML::Node.new('text', xml.doc)
          node.content = link.text
          xml.parent << node
        end
        xml.type link.type if link.type
      end
    end

    def build_bounds(xml, bounds)
      xml.bounds(
        'minlat' => bounds.minlat,
        'minlon' => bounds.minlon,
        'maxlat' => bounds.maxlat,
        'maxlon' => bounds.maxlon
      )
    end

    # Builds wpt / rtept / trkpt elements (all share the same field set).
    def build_waypoint(xml, wpt, tag: 'wpt')
      xml.send(tag, 'lat' => wpt.lat, 'lon' => wpt.lon) do
        xml.ele          wpt.ele                  if wpt.ele
        xml.time         wpt.time.iso8601         if wpt.time
        xml.magvar       wpt.magvar               if wpt.magvar
        xml.geoidheight  wpt.geoidheight          if wpt.geoidheight
        xml.name         wpt.name                 if wpt.name
        xml.cmt          wpt.cmt                  if wpt.cmt
        xml.desc         wpt.desc                 if wpt.desc
        xml.src          wpt.src                  if wpt.src
        Array(wpt.links).each { |link| build_link(xml, link) }
        xml.sym          wpt.sym                  if wpt.sym
        xml.type         wpt.type                 if wpt.type
        xml.fix          wpt.fix                  if wpt.fix
        xml.sat          wpt.sat                  if wpt.sat
        xml.hdop         wpt.hdop                 if wpt.hdop
        xml.vdop         wpt.vdop                 if wpt.vdop
        xml.pdop         wpt.pdop                 if wpt.pdop
        xml.ageofdgpsdata wpt.ageofdgpsdata       if wpt.ageofdgpsdata
        xml.dgpsid       wpt.dgpsid               if wpt.dgpsid
      end
    end

    def build_route(xml, route)
      xml.rte do
        xml.name   route.name   if route.name
        xml.cmt    route.cmt    if route.cmt
        xml.desc   route.desc   if route.desc
        xml.src    route.src    if route.src
        Array(route.links).each { |link| build_link(xml, link) }
        xml.number route.number if route.number
        xml.type   route.type   if route.type
        route.points.each { |pt| build_waypoint(xml, pt, tag: 'rtept') }
      end
    end

    def build_track(xml, track)
      xml.trk do
        xml.name   track.name   if track.name
        xml.cmt    track.cmt    if track.cmt
        xml.desc   track.desc   if track.desc
        xml.src    track.src    if track.src
        Array(track.links).each { |link| build_link(xml, link) }
        xml.number track.number if track.number
        xml.type   track.type   if track.type
        track.segments.each do |seg|
          xml.trkseg do
            seg.points.each { |pt| build_waypoint(xml, pt, tag: 'trkpt') }
          end
        end
      end
    end
  end
end
