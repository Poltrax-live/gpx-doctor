# frozen_string_literal: true

require 'nokogiri'
require 'time'

module GpxDoctor
  class Parser
    GPX_NS = 'http://www.topografix.com/GPX/1/1'

    Result = Struct.new(:waypoints, :routes, :tracks, :metadata, keyword_init: true) do
      def points
        waypoints + routes.flat_map(&:points) + tracks.flat_map(&:points)
      end
    end

    class << self
      def parse(file_path, params: {})
        xml = File.read(file_path)
        parse_string(xml, params: params)
      end

      def parse_string(xml_string, params: {})
        doc = Nokogiri::XML(xml_string)
        ns  = detect_namespace(doc)

        new(doc, ns, params: params).parse
      end

      private

      def detect_namespace(doc)
        root_ns = doc.root&.namespace&.href
        root_ns == GPX_NS ? GPX_NS : nil
      end
    end

    def initialize(doc, ns, params: {})
      @doc = doc
      @ns  = ns
      @params = params
    end

    def parse
      result = Result.new(
        waypoints: parse_waypoints,
        routes: parse_routes,
        tracks: parse_tracks,
        metadata: parse_metadata
      )

      enhance_elevations(result) if GpxDoctor.configuration.elevation_server

      eff_max_dist = effective_max_distance(result)
      split_segments(result, eff_max_dist) if eff_max_dist
      select_max_points(result) if @params[:max_points]
      enhance_statistics(result) if @params[:segment_statistics]

      result
    end

    private

    def xpath(node, path)
      if @ns
        node.xpath(path, 'g' => @ns)
      else
        node.xpath(path.gsub('g:', ''))
      end
    end

    def text_at(node, tag)
      el = xpath(node, "g:#{tag}").first
      el&.text&.strip
    end

    def float_at(node, tag)
      v = text_at(node, tag)
      v&.to_f
    end

    def int_at(node, tag)
      v = text_at(node, tag)
      v&.to_i
    end

    def time_at(node, tag)
      v = text_at(node, tag)
      v ? Time.parse(v) : nil
    end

    def parse_links(node)
      xpath(node, 'g:link').map do |link_el|
        Models::Link.new(
          href: link_el['href'],
          text: link_el.xpath('g:text', 'g' => @ns).first&.text&.strip,
          type: link_el.xpath('g:type', 'g' => @ns).first&.text&.strip
        )
      end
    end

    def parse_waypoint(wpt_el)
      Models::Waypoint.new(
        lat: wpt_el['lat'].to_f,
        lon: wpt_el['lon'].to_f,
        ele: float_at(wpt_el, 'ele'),
        time: time_at(wpt_el, 'time'),
        magvar: float_at(wpt_el, 'magvar'),
        geoidheight: float_at(wpt_el, 'geoidheight'),
        name: text_at(wpt_el, 'name'),
        cmt: text_at(wpt_el, 'cmt'),
        desc: text_at(wpt_el, 'desc'),
        src: text_at(wpt_el, 'src'),
        links: parse_links(wpt_el),
        sym: text_at(wpt_el, 'sym'),
        type: text_at(wpt_el, 'type'),
        fix: text_at(wpt_el, 'fix'),
        sat: int_at(wpt_el, 'sat'),
        hdop: float_at(wpt_el, 'hdop'),
        vdop: float_at(wpt_el, 'vdop'),
        pdop: float_at(wpt_el, 'pdop'),
        ageofdgpsdata: float_at(wpt_el, 'ageofdgpsdata'),
        dgpsid: int_at(wpt_el, 'dgpsid')
      )
    end

    def parse_waypoints
      xpath(@doc, '//g:gpx/g:wpt').map { |el| parse_waypoint(el) }
    end

    def parse_routes
      xpath(@doc, '//g:gpx/g:rte').map do |rte_el|
        Models::Route.new(
          name: text_at(rte_el, 'name'),
          cmt: text_at(rte_el, 'cmt'),
          desc: text_at(rte_el, 'desc'),
          src: text_at(rte_el, 'src'),
          links: parse_links(rte_el),
          number: int_at(rte_el, 'number'),
          type: text_at(rte_el, 'type'),
          points: xpath(rte_el, 'g:rtept').map { |el| parse_waypoint(el) }
        )
      end
    end

    def parse_tracks
      xpath(@doc, '//g:gpx/g:trk').map do |trk_el|
        Models::Track.new(
          name: text_at(trk_el, 'name'),
          cmt: text_at(trk_el, 'cmt'),
          desc: text_at(trk_el, 'desc'),
          src: text_at(trk_el, 'src'),
          links: parse_links(trk_el),
          number: int_at(trk_el, 'number'),
          type: text_at(trk_el, 'type'),
          segments: xpath(trk_el, 'g:trkseg').map do |seg_el|
            Models::TrackSegment.new(
              points: xpath(seg_el, 'g:trkpt').map { |el| parse_waypoint(el) }
            )
          end
        )
      end
    end

    def parse_metadata
      meta_el = xpath(@doc, '//g:gpx/g:metadata').first
      return nil unless meta_el

      Models::Metadata.new(
        name: text_at(meta_el, 'name'),
        desc: text_at(meta_el, 'desc'),
        author: parse_person(xpath(meta_el, 'g:author').first),
        copyright: parse_copyright(xpath(meta_el, 'g:copyright').first),
        links: parse_links(meta_el),
        time: time_at(meta_el, 'time'),
        keywords: text_at(meta_el, 'keywords'),
        bounds: parse_bounds(xpath(meta_el, 'g:bounds').first)
      )
    end

    def parse_person(person_el)
      return nil unless person_el

      Models::Person.new(
        name: text_at(person_el, 'name'),
        email: parse_email(xpath(person_el, 'g:email').first),
        link: parse_links(person_el).first
      )
    end

    def parse_email(email_el)
      return nil unless email_el

      Models::Email.new(
        id: email_el['id'],
        domain: email_el['domain']
      )
    end

    def parse_copyright(copyright_el)
      return nil unless copyright_el

      Models::Copyright.new(
        author: copyright_el['author'],
        year: text_at(copyright_el, 'year'),
        license: text_at(copyright_el, 'license')
      )
    end

    def parse_bounds(bounds_el)
      return nil unless bounds_el

      Models::Bounds.new(
        minlat: bounds_el['minlat'].to_f,
        minlon: bounds_el['minlon'].to_f,
        maxlat: bounds_el['maxlat'].to_f,
        maxlon: bounds_el['maxlon'].to_f
      )
    end

    def enhance_elevations(result)
      ElevationClient.new.enhance(result.points)
    end

    def effective_max_distance(result)
      return @params[:max_distance] if @params[:max_distance]
      return nil unless @params[:max_points]

      total = total_distance(result)
      ratio = total / @params[:max_points].to_f
      ratio > 1000 ? 500 : nil
    end

    def total_distance(result)
      selector = PointSelector.new
      all_point_collections(result).sum { |pts| selector.total_distance(pts) }
    end

    def all_point_collections(result)
      collections = result.routes.map(&:points)
      result.tracks.each { |t| t.segments.each { |s| collections << s.points } }
      collections
    end

    def split_segments(result, max_dist)
      splitter = SegmentSplitter.new
      result.routes.each { |route| route.points = splitter.split(route.points, max_dist) }
      result.tracks.each do |track|
        track.segments.each { |seg| seg.points = splitter.split(seg.points, max_dist) }
      end
    end

    def select_max_points(result)
      selector = PointSelector.new
      n = @params[:max_points]
      result.routes.each { |route| route.points = selector.select(route.points, n) }
      result.tracks.each do |track|
        track.segments.each { |seg| seg.points = selector.select(seg.points, n) }
      end
    end

    def enhance_statistics(result)
      enhancer = StatisticsEnhancer.new
      result.routes.each { |route| enhancer.enhance(route.points) }
      result.tracks.each do |track|
        track.segments.each { |seg| enhancer.enhance(seg.points) }
      end
    end
  end
end
