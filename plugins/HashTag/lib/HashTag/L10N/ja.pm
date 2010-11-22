package HashTag::L10N::ja;

use strict;
use base 'HashTag::L10N::en_us';
use vars qw( %Lexicon );

## The following is the translation table.

%Lexicon = (
	'Tweet with HashTag' => 'ハッシュタグ付きでツイート',
	'Don\'t Tweet' => 'ツイートしない',
	'Tweet without HashTags' => 'ハッシュタグ無しでツイート',
	'Tweet with #[_1]' => '#[_1]を付けてツイート',
	'Tweet tags as HashTags' => 'タグをハッシュタグにしてツイート',
	'Introduction' => '最初の部分',
	'Precedes the post title and url.' => 'タイトルとURLの前に挿入',
	'Hash Tag' => 'ハッシュタグ',
	'Default hashtag' => 'デフォルトのハッシュタグ',
	'By default' => 'デフォルト動作',
	'Use default HashTag' => 'デフォルトのハッシュタグを使う',
	'Use entry tags as HashTags' => 'ブログ記事のタグをハッシュタグにする',
	'bit.ly login:' => 'bit.ly ログイン:',
	'bit.ly apikey:' => 'bit.ly APIキー:',
	'bit.ly ver:' => 'bit.ly バージョン:',
	'Enable History:' => '履歴を有効にする:',
	'Automate tweeting your entries including hashtags.' => 'ブログ記事のハッシュタグ付きツイートを自動化します。',
);

1;

