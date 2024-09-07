#!/usr/bin/python3

from datetime import datetime

post_title = input("Insira o título do seu rascunho:")

time = datetime.now()
time_str = time.strftime("%Y-%m-%d")
tz = datetime.now().astimezone().tzname()
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
filename = "".join([x if x.isalnum() or x in '.' else "-" for x in filename])


with open('./_drafts/' + filename, 'w+') as file:
    file.write(post_content)
