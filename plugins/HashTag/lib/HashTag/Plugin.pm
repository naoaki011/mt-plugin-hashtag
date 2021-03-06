package HashTag::Plugin;

use strict;
use warnings;
use MT;
use MT::OAuth;
use MT::Util qw( xliterate_utf8 );

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
    if ( ($cfg->{tw_share} || 0) eq '0' || ($app->param('tw_share') || 0) eq '0' ) { $selected_0 = 'selected="selected"'; }
    if ( ($cfg->{tw_share} || 0) eq '1' || ($app->param('tw_share') || 0) eq '1' ) { $selected_1 = 'selected="selected"'; }
    if ( ($cfg->{tw_share} || 0) eq '2' || ($app->param('tw_share') || 0) eq '2' ) { $selected_2 = 'selected="selected"'; }
    if ( ($cfg->{tw_share} || 0) eq '3' || ($app->param('tw_share') || 0) eq '3' ) { $selected_3 = 'selected="selected"'; }

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
        if ($mtversion >= 5.1) {
            $$tmpl =~ s{(<mtapp:widget
   id="entry-publishing-widget")}{$setting$1}msg;
        }
        else {
            $$tmpl =~ s{(<mtapp:widget
    id="entry-publishing-widget")}{$setting$1}msg;
        }

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

sub hdlr_pre_preview {
    my ($cb, $app, $obj, $data) = @_;
    my $tw_share = $app->param('tw_share');
    if($tw_share) {
        push @$data,
        {
            data_name => 'tw_share',
            data_value => $tw_share
        };
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
        $tagname = xliterate_utf8($tagname); # convert high ascii
        $tagname =~ s/&/and/g;               # convert & to and
        $tagname =~ s/\'//g;                 # 
        $tagname =~ s/\"//g;                 # 
        $tagname =~ s/\./_/g;                # 
        $tagname =~ s/\$//g;                 # 
        $tagname =~ s/\#//g;                 # 
        $tagname =~ s/\!//g;                 # 
        $tagname =~ s/\%/per/g;              # 
        $tagname =~ s/\s+/_/g;               # convert space to _
        if ( $tagname =~ /^\w+$/ ) {         # except non ascii
            my $tag = MT::Tag->new;
            $tag->name($tagname);
            push( @normalized, $tag->normalize );
        }
    }
    my $hashtag = join( ' #', @normalized );
    $hashtag ? MT::I18N::length_text($hashtag) : 0;

    if ( $hashtag ) {
        return ' #' . $hashtag;
    } else {
        return
    }
}

sub _build_tweet {
    my ( $cfg, $obj, $app ) = @_;
    my $tweet = q{};
    my $intro = q{};
    my $title = q{};
    my $share = q{};

    my $author_id = $obj->author_id;

    if ( $cfg->{tw_intro} ) { $intro = $cfg->{tw_intro}; }
    if (substr(MT->version_number, 0, 3) >= 5.1) {
        $title = $obj->title;
    }
    else {
        my $enc = MT->instance->config('PublishCharset') || undef;
        $title = MT::I18N::encode_text( $obj->title, $enc, 'utf-8' );
    }
    
    # need to work out if _build_tweet has been called from a save action
    # or from a schedule post by checking if $app has the tw_share param
    # if not then it has been called from a schedule post so we need to use
    # the default configuration.

    my $entry_url;
    if ( $cfg->{use_bitly} ) {
        $entry_url = _bitly_shorten_v3($cfg,$obj->permalink);
    } else {
        $entry_url = _tinyurl_shorten($obj->permalink);
    }

    if ( defined { $app->param('tw_share') } ) {
        $share = $app->param('tw_share');
    } else {
        $share = $cfg->{tw_share};
    }

    if ( $intro ) { $tweet = $intro . ' '; }
    $tweet .= $title . ' ' . $entry_url;
    if ( $share eq '2' ) {
        if ( $cfg->{tw_community} ) {
            $tweet .= ' #' . $cfg->{tw_community};
        }
    }
    if ( $share eq '3' ) {
        $tweet .= _tag_to_hashtag($obj);
    }

    _update_twitter( $author_id, $tweet );

    return;
}

sub _update_twitter {
    my ( $author_id, $tweet ) = @_;
    my $tweet_debug = 0; # 1 is TestMode. Do not Tweet. only Log output.
    if ($tweet_debug) {
        MT->log( { message => 'TweetTest' . ' ' . $tweet, } );
    } else {
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

sub _tinyurl_shorten {
    my ($text) = @_;
    my $data;
    if ($text) {
        require LWP::Simple;
        my $api_url = "http://tinyurl.com/api-create.php?url=$text";
        my $tinyurl = LWP::Simple::get ($api_url)
            or return undef;
        $data = { URL => $tinyurl };
    }
    $data->{URL} || $text;
}

sub doLog {
    my ($msg) = @_; 
    return unless defined($msg);
    require MT::Log;
    my $log = MT::Log->new;
    $log->message($msg) ;
    $log->save or die $log->errstr;
}

1;

