##krawler: a fast parallel crawling framework in ruby
=======

Built on top of typhoeus, krawler crawls the urllist in parallel leading to super fast crawling compared to running your scraper linearly, one url at a time.

##Examples
You need to customize the match_response method dependending on the website you are trying to crawl in crawler.rb. Have a look at runner.rb for example

##Usage
```bash
ruby runner.rb
```

##Contributing
Welcoming pull requests, issues