# frozen_string_literal: true

require 'logger'
require 'net/http'
require 'nokogiri'
require 'pry-byebug'

INTERVAL_SEC = 3
USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.2 Safari/605.1.15' # Mac Safari
OUTPUT_DIR = 'out'
ROOT_URL = 'https://tower.jp/search/advanced/item/search?genre=01&subgenre=01&salesDiv=Reserv&echandling=y&recondition=True&format=114'

FavoriteArtist = ['OZWORLD', '槇原敬之']

FileUtils.mkdir_p(File.join("#{OUTPUT_DIR}"))

LOGGER = Logger.new(File.join(OUTPUT_DIR, 'crawling.log'))

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

    LOGGER.info("page:#{page} fetching")
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

    LOGGER.warn("crawling page:#{page} from outline failed")
    sleep(INTERVAL_SEC + i * 600) # 待つ時間を段階的に延ばしてみるS
  end
  raise 'detail page crawling blocked'
end

def last_page?(page, response)
  doc = Nokogiri::HTML.parse(response.body, nil, 'utf-8')
  last_page_number = doc.css('.pager li').last.text
  page >= last_page_number.to_i
end

page = 1

data = []

loop do
  begin
    response = fetch_data(page)
    break if response.code != "200" || last_page?(page, response)

    data << get_data(response)
    data.flatten!
  rescue StandardError => e
    LOGGER.error("page:#{page} error:#{e}")
  end

  page += 1
end

favorite_artist = data.select { |item| FavoriteArtist.include?(item['artist']) }

LOGGER.info("favorite_artist:#{favorite_artist}")

LOGGER.debug('finished')
