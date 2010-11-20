require 'vclog/adapters/abstract'

module VCLog
module Adapters

  # The GIT Adapter utilizes the +grit+ gem.
  #
  class Git < Abstract

    def initialize_framework
      require 'grit'
    end

    #
    def grit_repo
      @grit_repo ||= Grit::Repo.new(root)
    end

    # Collect changes.
    #
    def extract_changes
      list = []
      changelog = `git log --pretty=format:"\036|||%ci|~|%aN|~|%H|~|%s"`.strip
      changes = changelog.split("\036|||")
      #changes = changelog.split(/^commit/m)
      changes.shift # throw the first (empty) entry away
      changes.each do |entry|
        date, who, rev, msg = entry.split('|~|')
        date = Time.parse(date)
        list << [rev, date, who, msg]
      end
      list
    end

    # TODO
    #def extract_changes
    #  repo.commit.map do |commit|
    #    [commit.id, commit.date, commit.author.to_s, commit.message]
    #  end
    #end

    # Collect tags.
    #
    # `git show 1.0` produces:
    #
    #   tag 1.0
    #   Tagger: 7rans <transfire@gmail.com>
    #   Date:   Sun Oct 25 09:27:58 2009 -0400
    #
    #   version 1.0
    #   commit
    #   ...
    #
    def extract_tags
      list = []
      tags = `git tag -l`
      tags.split(/\s+/).each do |tag|
        next unless version_tag?(tag) # only version tags
        who, date, rev, msg = nil, nil, nil, nil
        info = `git show #{tag}`
        info, *_ = info.split(/^(commit|diff|----)/)
        if /\Atag/ =~ info
          msg = ''
          info.lines.to_a[1..-1].each do |line|
            case line
            when /^Tagger:/
              who  = $'
            when /^Date:/
              date = $'
            else
              msg << line
            end
          end
          msg = msg.strip
          info = `git show #{tag}^ --pretty=format:"%ci|~|%H|~|"`
          date, rev, *_ = *info.split('|~|')
        else
          info = `git show #{tag} --pretty=format:"%cn|~|%ce|~|%ci|~|%H|~|%s|~|"`
          who, email, date, rev, msg, *_ = *info.split('|~|')
          who = who + ' ' + email
        end          

        #if $DEBUG
        #  p who, date, rev, msg
        #  puts
        #end

        list << [tag, rev, date, who, msg]
      end
      list
    end

    # TODO
    #def extract_tags
    #  repo.tags.map do |tag|
    #    [tag.name, tag.commit.id, tag.commit.date, tag.commit.author.to_s, tag.commit.message]
    #  end
    #end

    #
    def user
      @user ||= grit_repo.config['user.name']
      #@user ||= `git config user.name`.strip
    end

    #
    def email
      @email ||= grit_repo.config['user.email']
      #@email ||= `git config user.email`.strip
    end

    #
    def repository
      @repository ||= grit_repo.config['remote.origin.url']
      #@repository ||= `git config remote.origin.url`.strip
    end

    # Create a tag for the given commit reference.
    def tag(ref, label, date, message)
      date = date.strftime('%y-%m-%d') unless String===date
      `GIT_COMMITTER_DATE="#{date}" git tag -a #{label} -m "#{message.inspect}" #{ref}`
    end

  end#class Git

end
end
