# compile a list of players people have 

require 'data_mapper'
require 'tzinfo'
require 'typhoeus'
require 'nokogiri'
@players = Array.new

def get_league
  puts "getting league"
  Teamplayer.destroy
  Team.destroy
  Player.destroy

  league_id = 21286
  leaguepage = Nokogiri::HTML(Typhoeus::Request.get("http://fantasy.premierleague.com/my-leagues/#{league_id}/standings/").body)
  leaguepage.at(".ismStandingsTable").css("tr").each do |tr|
  	next unless tr.at_css("td")
  	team = Team.first_or_create(
  	  {:name => tr.css("td")[2].text},
  	  {:owner => tr.css("td")[3].text, :link => "http://fantasy.premierleague.com#{tr.css("td")[2].at("a")["href"]}", :updated_at => Time.now}
  	)
  end
  
  hydra = Typhoeus::Hydra.new
  for team in Team.all
    team_request = Typhoeus::Request.new(team.link)
    team_request.on_complete { |response| parseteam(response) }
    hydra.queue team_request
  end
  hydra.run

end

def parseteam(response)
  
  teampage = Nokogiri::HTML(response.body)
  team = Team.first(:link => response.effective_url)
  team.owner = team.owner.gsub("S  lve","S&oslash;lve").gsub("J  rgen","J&oslash;rgen")
  team.oldtotal = teampage.css(".ismModBody .ismRHSDefList dd")[0].text.gsub(",","").to_i
  team.oldpoints = teampage.css(".ismModBody .ismRHSDefList dd")[3].text.to_i
  team.transfers = teampage.css(".ismSBDefList dd")[1].text.strip.gsub(/[ \n]{2,}/," ").gsub("pts","")
  nr = 0
  teampage.css(".ismPlayerContainer").each do |container|
    dataline = teampage.css(".ismMTData #ismDataElements tr")[nr].css("td")
    player_name = container.at(".ismPitchWebName").text.strip
    @players << player_name
    
  end # container
  

end # def parseteam


private

#data mappings

DataMapper.setup(:default, "in_memory::")
DataMapper::Model.raise_on_save_failure = true

class Teamplayer
  include DataMapper::Resource  
  property :id,           Serial  
  property :captain,      Boolean
  property :vicecaptain,  Boolean
  property :points,       Integer
  property :bench,        Boolean  
  belongs_to :player
  belongs_to :team
end

class Team
  include DataMapper::Resource  
  @@colors = ['#ccffcc','#ffcccc','#ccccff','#ffffcc','#ccffff','#ffccff','#cccccc']
  property :id,           Serial
  property :name,         String
  property :owner,        String
  property :oldtotal,     Integer
  property :oldpoints,    Integer
  property :total,        Integer
  property :transfers,    String
  property :color,        String
  property :link,         Text
  property :updated_at,   DateTime
  has n, :teamplayers

  def eleven
  	teamplayers(:bench => false).players
  end
  
  def playersleft
    teamplayers(:bench => false).players(:played => false).all.length
  end
  
  def points
  	points = 0
  	for teamplayer in teamplayers(:bench => false)
  	  points += teamplayer.points
  	end
  	return points
  end
  
  def ownershort
  	owner.split(" ").first
  end
  
  before :create do |team|
    team.color = @@colors.empty? ? "white" : @@colors.pop
  end

end

class Player
  include DataMapper::Resource  
  property :id,           Serial
  property :name,         String
  property :squad,        String
  property :points,       Integer
  property :played,       Boolean
  has n, :teamplayers
end

DataMapper.auto_upgrade!



get_league
puts "#{@players.length} playaz"
