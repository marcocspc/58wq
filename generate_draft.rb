#!/usr/bin/ruby

puts "Insira o título do seu rascunho:"
post_title = gets.gsub("\n", "")

time = Time.new
time_str = time.strftime("%Y-%m-%d")
tz = time.zone + "00"
date_str = time.strftime("%Y-%m-%d %k:%M:%S " + tz)



post_content = """---
layout: post
title:  \"#{post_title}\"
date:  #{date_str} 
categories: cat1 cat2 cat3  
---

# #{post_title} 

Só um exemplo de conteúdo.
"""

filename = time_str + "-" + post_title + ".md" 
filename = filename.gsub(/[\x00\/\\:\*\?\"<>\|]/, "-")
filename = filename.gsub(" ", "-")


File.write('./_drafts/' + filename, post_content)
