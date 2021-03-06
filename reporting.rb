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

def time_format(seconds)
  minutes = seconds / 60
  hours = (minutes / 60)
  minutes = minutes % 60
  "#{hours}h#{minutes}"
end

def strip_tags(text)
  text.gsub(/(<.*?>)/, '')
end

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

argv = ARGV.map(&:downcase)

start_min, start_max = if argv.include?('weekly')
  [Time.now.beginning_of_week.utc.xmlschema, Time.now.end_of_week.utc.xmlschema]
elsif argv.include?('monthly')
  [Time.now.beginning_of_month.utc.xmlschema, Time.now.end_of_month.utc.xmlschema]
else
  [Time.now.beginning_of_day.utc.xmlschema, Time.now.end_of_day.utc.xmlschema]
end

service = GCal4Ruby::Service.new
service.authenticate(CONFIG['google']['login'], CONFIG['google']['password'])

cal = GCal4Ruby::Calendar.find(service, CONFIG['google']['calendar']).first
events = GCal4Ruby::Event.find(service, '', {
  :calendar => cal.id,
  'max-results' => 500,
  'start-min' => start_min,
  'start-max' => start_max
})

durations = {}
events.each do |event|
  if !event.recurrence && !event.instance_variable_get('@all_day')
    duration = event.end_time.to_i - event.start_time.to_i
    key = event.title.slugify_trim
    durations[key] ||= {:title => event.title, :duration => 0}
    durations[key][:duration] += duration
  end
end

durations = durations.collect { |a, b| [a, b] }.sort { |a, b| a[0] <=> b[0] }
durations = ActiveSupport::OrderedHash[durations]

content = '<table cellspacing="0" cellpadding="0">'
content << durations.collect do |dc_title, infos|
  duration = time_format(infos[:duration])
  title = infos[:title].downcase.to_s.gsub(/(\A| )./) { |m| m.upcase }
  "<tr><td>#{title} </td><td>#{duration}</td></tr>\n"
end.join
content << '</table>'

puts strip_tags(content)

duration = durations.collect { |key, infos| infos[:duration] }.sum
puts "Total des heures : #{time_format duration}"

comment = question('Un commentaire à ajouter ?')

unless comment.blank?
  content << "\n<p>#{comment}</p>"
  puts strip_tags(content)
end

if yes_no_question "Envoyer l'e-mail ?"
  content << '<style> td, p { padding: 5px; } </style>'
  ReportMailer.create_email(content).deliver
  puts "e-mail envoyé à #{CONFIG['email']['to']}"
end