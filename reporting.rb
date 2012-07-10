require 'config'

class ReportMailer < ActionMailer::Base

  def create_email(content)
    mail(
      :to       => CONFIG['email']['to'],
      :bcc      => CONFIG['email']['from'],
      :subject  => CONFIG['email']['subject'],
      :from     => CONFIG['email']['from'],
      :body     => content
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

max_length = 0

durations = {}
events.each do |event|
  unless event.recurrence
    max_length = event.title.size if max_length < event.title.size
    duration = event.end_time - event.start_time
    durations[event.title] ||= 0
    durations[event.title] += duration
  end
end

max_length +=5

content = durations.collect do |title, duration|
  duration = Time.at(duration).strftime("%Hh%M").gsub(/^0/, '')
  "#{title.ljust(max_length)} #{duration}"
end.join("\n")

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

puts content

comment = question('Un commentaire à ajouter ?')
content << "\n\n#{comment}" unless comment.blank?

puts content

if yes_no_question "Envoyé l'e-mail ?"
  ReportMailer.create_email(content).deliver
  puts 'e-mail envoyé'
end