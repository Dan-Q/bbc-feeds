# BBC News RSS Feeds (that don't suck!)

## The Feeds

You can find all the feeds at https://bbc-feeds.danq.dev/

## What is this?

BBC News provides a variety of RSS feeds for subscribing to news content. But they're not great, so I've been working on improving them:

1. In 2019, sick of seeing sports news (that I didn't care about), I started [filtering out sports](https://danq.me/2019/05/14/bbc-news-without-the-sport/).
2. In 2024, the feed started being polluted by non-news content (links to iPlayer and BBC Sounds content, and plugs for the app). So [I came up with a filter for them too](https://danq.me/2019/05/14/bbc-news-without-the-sport/).
3. In 2025, a commenter asked if I could make an alternate version of the feed that didn't exclude the sports news, [so I arranged for that too](https://danq.me/2025/02/03/bbc-news-rss-improved/).
4. Finally, when somebody asked on Mastodon whether I could start filtering not only the UK edition but also the World edition of BBC News... [I realised it was time to turn this into a proper project](https://danq.me/2025/02/08/bbc-news-rss-your-way/).

## How does it work?

If you want to run it for yourself:

1. Check out this codebase.
2. Using Ruby 3.3.4 or later, run `bundle install` to install dependencies.
3. Run `ruby ./pull-feeds.rb`.
4. The resulting feeds can be found in `build/`.

Set up step 3 on a cron job every ~20 minutes or so, and you're all set.

`.github/workflows/deploy.yaml` defines the above process as a Github Action. If you're copying this for your own Github Pages repo, you'll need to change the domain name in `pull-feeds.rb` and `.github/workflows/deploy.yaml` to your own.

## License

This project is released under The Unlicense. See [LICENSE](LICENSE) for more information, but the tl;dr: is that you can do whatever you want with this code, without any restrictions.
