require 'digest/sha1'

class HackerNews < Linkbot::Plugin
  Linkbot::Plugin.register('hn', self,
    {
      :message => {:regex=> /!hn(?: (.+))?/, :handler=> :on_message, :help => :help},
      :periodic => {:handler => :periodic}
    }
  )

  if Linkbot.db.table_info('hn').empty?
    Linkbot.db.execute('CREATE TABLE hn (hash STRING, comment STRING, user STRING, category STRING)');
    Linkbot.db.execute('create index hn_comment_idx on hn (hash)')
    Linkbot.db.execute('create index hn_cat_idx on hn (category collate nocase)')
  end

  def self.on_message(message, matches)
    if matches[0]
      res = Linkbot.db.execute("select comment,user from hn where category=?", matches[0])
      if res.length > 0
        comment = res[rand(res.length)]
        "#{comment[0]} - #{comment[1]}"
      else
        "No HN comments in that category!"
      end
    else
      begin
        site = "https://news.ycombinator.com/newcomments"
        doc = Hpricot(open(site).read)
        comments = doc.search("td.default")
        rand_comment = comments[rand(comments.length)]

        user = rand_comment.search("a")[0].inner_text
        comment = rand_comment.search("font")[0].inner_text
        "#{comment} - #{user}"
      rescue
        "Stupid Hacker News is down."
      end
    end
  end

  def self.periodic
    site = "https://news.ycombinator.com/newcomments"
    doc = Hpricot(open(site).read)
    comments = doc.search("td.default")

    comments.each do |comment|
      comment_text = comment.search("font")[0].inner_text
      user = comment.search("a")[0].inner_text
      hash = Digest::SHA1.hexdigest(comment_text)

      # Make sure this comment is saved already
      res = Linkbot.db.execute("select * from hn where hash='#{hash}'")
      if res.length == 0
        if comment_text =~ /nsa/i
          Linkbot.db.execute("insert into hn (hash, comment, user, category) VALUES (?,?,?,?)",
            hash,
            comment_text,
            user,
            'nsa')
        end
        if comment_text =~ /google/i
          Linkbot.db.execute("insert into hn (hash, comment, user, category) VALUES (?,?,?,?)",
            hash,
            comment_text,
            user,
            'google')
        end
        if comment_text =~ /apple/i
          Linkbot.db.execute("insert into hn (hash, comment, user, category) VALUES (?,?,?,?)",
            hash,
            comment_text,
            user,
            'apple')
        end
      end
    end

    {:messages => [], :options => {}}
  end

  def self.help
    "!hn - Random recent HN comment"
  end
end