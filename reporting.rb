require 'config'

class ReportMailer < ActionMailer::Base

  def create_email(content)
    mail(
      :to           => CONFIG['email']['to'],
      :bcc          => CONFIG['email']['from'],
      :subject      => CONFIG['email']['subject'],
      :from         => CONFIG['email']['from'],
      :body         => content,
      :content_type => 'text/html'
    )
  end

end

service = GCal4Ruby::Service.new

service.authenticate(CONFIG['google']['login'], CONFIG['google']['password'])

cal = GCal4Ruby::Calendar.find(service, CONFIG['google']['calendar']).first
events = GCal4Ruby::Event.find(service, '', {
  :calendar => cal.id,
  'start-min' => Time.now.beginning_of_day.utc.xmlschema,
  'start-max' => Time.now.end_of_day.utc.xmlschema
})

durations = {}
events.each do |event|
  unless event.recurrence
    duration = event.end_time - event.start_time
    key = event.title.slugify_trim
    durations[key] ||= {:title => event.title, :duration => 0}
    durations[key][:duration] += duration
  end
end

durations = durations.collect { |a, b| [a, b] }.sort { |a, b| a[0] <=> b[0] }
durations = ActiveSupport::OrderedHash[durations]

content = '<table cellspacing="0" cellpadding="0">'
content << durations.collect do |dc_title, infos|
  duration = Time.at(infos[:duration]).strftime("%Hh%M").gsub(/^0/, '')
  title = infos[:title].downcase.to_s.gsub(/(\A| )./) { |m| m.upcase }
  "<tr><td>#{title} </td><td>#{duration}</td></tr>\n"
end.join
content << '</table>'

@shell = Thor::Base.shell.new

def question(message)
  @shell.ask message.green
end

def yes_no_question(message)
  answer = question "#{message.green} #{'(yes/no)'.yellow}"
  case answer.downcase
    when 'yes', 'y'
      true
    when 'no', 'n'
      false
    else
      yes_no_question(message)
  end
end

def strip_tags(text)
  text.gsub(/(<.*?>)/, '')
end

puts strip_tags(content)

comment = question('Un commentaire à ajouter ?')

unless comment.blank?
  content << "\n<p>#{comment}</p>"
  puts strip_tags(content)
end

if yes_no_question "Envoyé l'e-mail ?"
  content << '<style> td, p { padding: 5px; } </style>'
  ReportMailer.create_email(content).deliver
  puts 'e-mail envoyé'
end