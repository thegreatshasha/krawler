##krawler: a fast parallel crawling framework in ruby
=======

Built on top of typhoeus, krawler crawls the urllist in parallel leading to super fast crawling compared to running your scraper linearly, one url at a time.

##Examples
You need to customize the match_response method dependending on the website you are trying to crawl in crawler.rb. Have a look at runner.rb for example

##Features
* Serial and parallel crawling of url's
* Allow random delay between requests for sites that block heavy traffic from same ip
* Debug levels for output
* Spoof browser headers randomly to make requests look different
* Plugin for proxy rotation for allowing requests to run through different ips
* Helper to read write links

##Usage
```bash
ruby runner.rb
```

##Contributing
Welcoming pull requests, issues and any other form of contribution.