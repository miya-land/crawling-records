# frozen_string_literal: true

require 'net/http'
require 'nokogiri'
require 'aws-sdk-sns'

module LambdaFunction
  class Handler

    INTERVAL_SEC = 3
    USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.2 Safari/605.1.15' # Mac Safari
    ROOT_URL = 'https://tower.jp/search/advanced/item/search?genre=01&subgenre=01&salesDiv=Reserv&echandling=y&recondition=True&format=114'

    FavoriteArtist = ['OZworld', '槇原敬之']

    def self.process(event:, context:)
        sns = Aws::SNS::Client.new(region: 'ap-northeast-1') # 適切なリージョンを指定
        page = 1
        data = []
        loop do
          begin
            response = fetch_data(page)
            break if response.code != "200" || last_page?(page, response)
            data << get_data(response)
          rescue StandardError => e 
            puts 'Error: #{e.message}'
          end
          page += 1
        end
        data.flatten!
        puts 'finish fetching data'

        favorite_artist = data.select { |item| FavoriteArtist.include?(item['artist']) }
        text = favorite_artist.map { |item| "#{item['title']} - #{item['artist']}" }.join("\n")
        params = {
          topic_arn: 'arn:aws:sns:ap-northeast-1:423513201913:practice', # 適切なトピックARNを指定
          message: 'Favorite Artistの新着情報があります\n' + text,
          subject: 'Test Message'
        }
        begin
          sns.publish(params)
        rescue StandardError => e
          puts 'Error: #{e.message}'
        end
    end

    private

      def get_data(response)
        doc = Nokogiri::HTML.parse(response.body, nil, 'utf-8')
        data = []
        doc.css('.artistSectionLine01')&.each do |item|
          item.css('li').each do |li|
            data << {
              'title' => li.css('.title a').text || '',
              'artist' => li.css('.artist a').text || '',
            }
          end
        end

        data
      end

      # @return [Nokogiri::HTML::Document]
      def fetch_data(page)
        5.times do |i| # 5回駄目なら打ち切り
          sleep(INTERVAL_SEC)

          puts "page:#{page} fetching"
          uri = URI.parse("#{ROOT_URL}&page=#{page}")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          headers = {
            'Referer' => ROOT_URL,
            'User-Agent' => USER_AGENT
          }
          http.open_timeout = 60
          http.read_timeout = 60
          response = http.get(uri.request_uri, headers)

          if response.code == "200"
            return response
          end

          puts "crawling page:#{page} from outline failed"
          sleep(INTERVAL_SEC + i * 600) # 待つ時間を段階的に延ばしてみるS
        end
        raise 'detail page crawling blocked'
      end

      def last_page?(page, response)
        doc = Nokogiri::HTML.parse(response.body, nil, 'utf-8')
        last_page_number = doc.css('.pager li').last.text
        page >= last_page_number.to_i
      end
  end
end
