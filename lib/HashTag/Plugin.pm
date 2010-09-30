package HashTag::Plugin;

use strict;
use warnings;
use MT;
use MT::OAuth;
use MT::Util qw( dirify );


sub instance {
    return mt->component("HashTag");
}

sub xfrm_edit {
    my ( $cb, $app, $tmpl ) = @_;
    my $cfg        = instance()->get_config_hash( 'blog:' . $app->blog->id );
    my $selected_0 = q{};
    my $selected_1 = q{};
    my $selected_2 = q{};
    my $selected_3 = q{};
    if ( $cfg->{tw_share} eq '0' ) { $selected_0 = 'selected="selected"'; }
    if ( $cfg->{tw_share} eq '1' ) { $selected_1 = 'selected="selected"'; }
    if ( $cfg->{tw_share} eq '2' ) { $selected_2 = 'selected="selected"'; }
    if ( $cfg->{tw_share} eq '3' ) { $selected_3 = 'selected="selected"'; }

    my $mtversion  = substr(MT->version_number, 0, 3);
    if ($mtversion >= 5) {

        my $setting = <<END_TMPL;
    <mtapp:widget
        id="tw_share"
        label="<__trans_section component="HashTag"><__trans phrase="Tweet with HashTag"></__trans_section>">
        <select name="tw_share" id="tw_share" class="full-width">
            <option value="0" $selected_0 ><__trans_section component="HashTag"><__trans phrase="Don\'t Tweet"></__trans_section></value>
            <option value="1" $selected_1 ><__trans_section component="HashTag"><__trans phrase="Tweet without HashTags"></__trans_section></option>
            <option value="2" $selected_2 ><__trans_section component="HashTag"><__trans phrase="Tweet with #[_1]" params="$cfg->{tw_community}"></__trans_section></option>
            <option value="3" $selected_3 ><__trans_section component="HashTag"><__trans phrase="Tweet tags as HashTags"></__trans_section></option>
        </select>
    </mtapp:widget>
END_TMPL

        $$tmpl =~ s{(<mtapp:widget
    id="entry-publishing-widget")}{$setting$1}msg;

    } else {

        my $setting = <<END_TMPL;
    <mtapp:setting
        id="tw_share"
        label="<__trans_section component="HashTag"><__trans phrase="Tweet with HashTag"></__trans_section>">
        <select name="tw_share" id="tw_share" class="full-width">
            <option value="0" $selected_0 ><__trans_section component="HashTag"><__trans phrase="Don\'t Tweet"></__trans_section></value>
            <option value="1" $selected_1 ><__trans_section component="HashTag"><__trans phrase="Tweet without HashTags"></__trans_section></option>
            <option value="2" $selected_2 ><__trans_section component="HashTag"><__trans phrase="Tweet with #[_1]" params="$cfg->{tw_community}"></__trans_section></option>
            <option value="3" $selected_3 ><__trans_section component="HashTag"><__trans phrase="Tweet tags as HashTags"></__trans_section></option>
        </select>
    </mtapp:setting>
END_TMPL

        $$tmpl =~ s{(<mtapp:setting
            id="status"
            label="<__trans phrase="Status">"
            help_page="entries"
            help_section="status">)}{$setting$1}msg;

    }
}

sub hdlr_post_save {
    my ( $cb, $app, $obj, $orig ) = @_;
    my $cfg = instance()->get_config_hash( 'blog:' . $app->blog->id );

    return $obj unless $app->param('tw_share');
    return $obj if $obj->status != MT::Entry::RELEASE();

    _build_tweet( $cfg, $obj, $app );
}

sub hdlr_scheduled_post {
    my ( $cb, $app, $obj ) = @_;
    my $cfg = instance()->get_config_hash( 'blog:' . $obj->blog_id );

    return $obj unless $cfg->{tw_share};
    return $obj if $obj->status != MT::Entry::RELEASE();

    _build_tweet( $cfg, $obj, $app );
}

sub _tag_to_hashtag {

    # convert entry tags into hash tags and populate $hashtags
    # thanks to Jay Allen http://endevver.com/

    my ( $obj ) = @_;
    require MT::Tag;
    my @normalized;
    foreach my $tagname ( $obj->tags ) {
        next unless index( $tagname, '@' );
        my $dirified_tag = dirify($tagname);
        if ($dirified_tag) {
            my $tag = MT::Tag->new;
            $tag->name($tagname);
            push( @normalized, $tag->normalize );
        }
    }
    my $hashtag = ' #' . join( ' #', @normalized );
    $hashtag ? MT::I18N::length_text($hashtag) : 0;

    return $hashtag;
}

sub _build_tweet {
    my ( $cfg, $obj, $app ) = @_;
    my $tweet = q{};
    my $intro = q{};
    my $title = q{};
    my $share = q{};

    my $author_id = $obj->author_id;

    if ( $cfg->{tw_intro} ) { $intro = $cfg->{tw_intro}; }

    my $enc = MT->instance->config('PublishCharset') || undef;
    $title = MT::I18N::encode_text( $obj->title, $enc, 'utf-8' );
    
    # need to work out if _build_tweet has been called from a save action
    # or from a schedule post by checking if $app has the tw_share param
    # if not then it has been called from a schedule post so we need to use
    # the default configuration.

    my $entry_url;
    if ( $cfg->{bitly_login} && $cfg->{bitly_apikey} ) {
        $entry_url = _bitly_shorten_v3($cfg,$obj->permalink);
    } else {
        $entry_url = $obj->permalink;
    }

    if ( defined { $app->param('tw_share') } ) {
        $share = $app->param('tw_share');
    } else {
        $share = $cfg->{tw_share};
    }

    if ( $share eq '1' ) {
        $tweet = $intro . ' ' 
        . $title . ' ' 
        . $entry_url;
    }
    if ( $share eq '2' ) {
        $tweet =
            $intro . ' ' 
          . $title . ' '
          . $entry_url . ' #'
          . $cfg->{tw_community};
    }
    if ( $share eq '3' ) {
        $tweet =
          $intro . ' ' 
        . $title . ' ' 
        . $entry_url 
        . _tag_to_hashtag($obj);
    }

    _update_twitter( $author_id, $tweet );

    return;
}

sub _update_twitter {
    my ( $author_id, $tweet ) = @_;
    my $tweet_debug = 1;
    if ($tweet_debug) {

    MT->log( { message => 'Tweeting' . ' ' . $tweet, } );
    my $client = MT::OAuth->client('twitter');
    return $client->access(
        author_id => $author_id,
        end_point => 'https://api.twitter.com/1/statuses/update.xml',
        post => {
            status => $tweet,
        },
        retry => 1,
    ) or MT->log( { message => 'Update to Twitter failed. Sorry.', } );

    } else {
    MT->log( { message => 'TweetTest' . ' ' . $tweet, } );
    }
}

sub _bitly_shorten_v3 {
    my ( $cfg, $text ) = @_;
    my $login   = $cfg->{bitly_login};
    my $apikey  = $cfg->{bitly_apikey};
    my $baseurl = $text;
    my $agent = 'HashTagsPlugin';
    my $ua = LWP::UserAgent->new(agent => $agent);
    my $biturl = "http://api.bit.ly/v3/shorten";
    my $res = $ua->post($biturl, [
        'longUrl' => $baseurl,
        'login'   => $login,
        'apiKey'  => $apikey,
        'format'  => 'json',
    ]);
    $res->is_success or return _save_log('Failed to get response from bit.ly',$baseurl);
    require JSON;
    my $obj = JSON::from_json($res->content) or return _save_log('Failed to get  shortened url from bit.ly',$baseurl);
    return _save_log('Failed to get  shortened url from bit.ly',$baseurl) if $obj->{errorCode};
    my $bitlyurl = $obj->{data}->{url};
    return $bitlyurl;
}

#sub _bitly_shorten_v2 {
#    my ( $cfg, $text ) = @_;
#    require HTTP::Lite;
#    require XML::DOM;
#    my $login   = $cfg->{bitly_login};
#    my $apikey  = $cfg->{bitly_apikey};
#    my $ver     = $cfg->{bitly_ver};
#    my $baseurl = $text;
#    my $history = $cfg->{bitly_history};
#    my $http = new HTTP::Lite;
#    my $resturl = "http://api.bit.ly/shorten?version=$ver&longUrl=$baseurl&login=$login&apiKey=$apikey&format=xml";
#    if ($history) {
#      $resturl .= "&history=1";
#    }
#    my $result = $http->request($resturl) || die $!;
#    my $xmlstr = $http->body();
#    my $parser = new XML::DOM::Parser;
#    my $doc = $parser->parse($xmlstr);
#    my $nodes = $doc->getElementsByTagName('shortUrl');
#    $text = $nodes->item(0)->getFirstChild->getNodeValue;
#    return $text;
#}

sub doLog {
    my ($msg) = @_; 
    return unless defined($msg);
    require MT::Log;
    my $log = MT::Log->new;
    $log->message($msg) ;
    $log->save or die $log->errstr;
}

1;

