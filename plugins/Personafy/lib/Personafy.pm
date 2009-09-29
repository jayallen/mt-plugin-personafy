package Personafy;

use strict;
use warnings;
# our $logger; use MT::Log::Log4perl qw( l4mtdump );

sub entry_persona_field()   { return "customfield_authorpersona" }
sub entry_submitter_field() { return "customfield_submitter" }

my %persona_meta = (
    user  => 'field.persona',
    entry => 'field.authorpersona'
);

#
# CMS_PRE_SAVE.ENTRY CALLBACK HANDLER 
#
# Handles entry saves executed via the MT admin UI (MT::App::CMS).
# In addition to storing author persona data for new entries, this
# routine must also support the use of Ghostwriter and handle its
# special application parameters.
sub cms_pre_save_entry {
    my ( $cb, $app, $obj, $original ) = @_;
    # $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my ($author, $author_id);

    # Save the original author for new and legacy entries
    persist_submitter( $app, $obj );

    # EXISTING ENTRY EXCLUSION                   # DETAILS
    return 1 if $obj->id                         # Existing entry
            and persona( $obj )                  # Has persona already
            and ! $obj->is_changed('author_id'); # No change in the author

    # BATCH EDIT MODE -- Return unless $obj/$original author_id different
    if ( $app->mode eq 'save_entries' ) {
        return 1 if $obj->author_id == $original->author_id;
        $author_id = $obj->author_id;
        $author    = $obj->author;
    }

    # $logger->info(
    #     join " ", 'STORING PERSONA FOR',
    #               ( $obj->id ? ' EXISTING' : 'NEW' ), 'ENTRY');
    # $logger->info('  OBJ->AUTHOR: ', $obj->author_id);
    # $logger->info('  ORIGINAL->AUTHOR: ', $original->author_id);

    $author_id ||= $app->param('new_author_id') || $obj->author_id;
    $author    ||= MT->model('user')->load( $author_id );
    
    # $logger->debug('DATA: ', l4mtdump(
    #     {
    #         cur_entry_persona  => persona( $obj ),
    #         new_user_persona  => persona( $author ),
    #         entry_author_id    => $obj->author_id,
    #         new_author_name    => $author->nickname,
    #         new_author_id      => $app->param('new_author_id'),
    #         original_author_id => $app->param('original_author_id'),
    #     }
    # ));

    persist_user_persona( $app, $obj, $author );
    1;
}

#
# API_PRE_SAVE.ENTRY CALLBACK HANDLER
#
# Handles generic, non-CMS saving of entry data. In the core MT code,
# this is called by Community, AtomServer and XMLRPCServer but it can be
# called by any arbitrary MT::App subclass or non-MT::App script or plugin
sub api_pre_save_entry {
    my ( $cb, $app, $entry, $orig ) = @_;
    # $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    # Save the original author for new and legacy entries
    persist_submitter( $app, $entry );
    1;
}

sub persist_submitter {
    my ( $app, $e, $user ) = @_;
    # $logger        ||= MT::Log::Log4perl->new(); $logger->trace();
    $user ||= ( $e->author || $app->user );
    # $logger->debug('USER: ', l4mtdump($user || {}));

    my $submitter = $e->meta('field.submitter');
    # $logger->debug("SUBMITTER: '$submitter'");

    if ( $user and ! $submitter ) {
        # $logger->info('SAVING SUBMITTER ID: ', $user->id);
        $e->meta('field.submitter', $user->id);
        $app->param(entry_submitter_field(), $user->id);
        $app->param('customfield_beacon', 1);
    }
}

sub persist_user_persona {
    my ( $app, $e, $user ) = @_;
    # $logger        ||= MT::Log::Log4perl->new(); $logger->trace();
    my $epersona     = persona( $e );
    my $persona      = persona( $user || $e->author ) or return;
    if ( $persona ne $epersona ) {
        # $logger->info('SAVING PERSONA: ', $persona);
        $app->param(entry_persona_field(), $persona);
        $app->param('customfield_beacon', 1);
    }
    return $persona;
}

sub persona {
    my $obj = shift or return;
    my $fieldname = $obj->isa( MT->model('entry') ) ? $persona_meta{entry}
                  : $obj->isa( MT->model('user') )  ? $persona_meta{user}
                                                    : undef;
    return defined $fieldname ? $obj->meta($fieldname): undef;
}

1;

__END__
