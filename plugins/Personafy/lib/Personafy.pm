package Personafy;

use strict;
use warnings;
our $logger; use MT::Log::Log4perl qw( l4mtdump );

sub entry_cust_field() { return "customfield_authorpersona" }

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
    $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my ($author, $author_id);

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

    $logger->info(
        join " ", 'STORING PERSONA FOR',
                  ( $obj->id ? ' EXISTING' : 'NEW' ), 'ENTRY');
    $logger->info('  OBJ->AUTHOR: ', $obj->author_id);
    $logger->info('  ORIGINAL->AUTHOR: ', $original->author_id);

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
    require Carp; import Carp qw( longmess );
    $app->log(
        message =>  (sprintf 'Personafy exception: Unhandled entry save by %s: %s',
                        ref($app), longmess()),
        level    => MT::Log::ERROR(),
        class    => 'entry',
    );
    1;
}

#
# MT::ENTRY::PRE_SAVE (OBJECT-LEVEL) CALLBACK HANDLER
#
# Serves as a fallback mechanism for persisting author personas in
# entries that are saved without triggering either the
# cms_pre_save.entry or api_pre_save.entry callbacks.
sub obj_pre_save_entry {
    my ($cb, $obj, $original) = @_;
return;
    # $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    # 
    # # We should only be operating on entries, not pages.
    # return unless 'entry' eq $obj->class_type;
    # 
    # # If an existing entry, only continue if the entry author has been modified
    # return if $obj->id and ! $obj->is_changed('author_id');
    # 
    # $logger->info('>>>>> Storing author metadata in entry <<<<<<');
    
    # my $app = MT->instance;
    # if ( $app ) {
    #     
    # }
    # my $oldauthor = $obj->author;
    # my $newauthor = MT->model('user')->load( $obj->author_id );
    # $persona = {
    #     author => { old => $obj->author->meta('field.persona'),
    #                 new => $newauthor->meta('field.persona') },
    #     entry  => $obj->meta('field.authorpersona'),
    #     )
    # 
    # 
    # 
    # my $entry_persona = ;
    # $logger->info('OBJ PERSONA: ', $persona);
    # my $newpersona = ;
    # $logger->info('NEW PERSONA: ', $newpersona);


    # $logger->debug('OBJ AUTHOR: ', l4mtdump(\$oldauthor));
    
    
# Anytime an entry is created in any of the blogs in the system, the plugin
# should check the author's Persona (basename: persona, tag: AuthorDataPersona)
# custom field.  If the value is something other than 0 (which is the default
# dropdown setting), that value should be copied into a global entry custom field
# called Author Persona (basename: authorpersona, tag: EntryDataAuthorPersona).
# 
# The plugin should not update this entry custom field when another
# user edit's the entry. The only time the field should change is if
# the author of the entry changes. (e.g. batch edit, Ghostwriter plugin).
# The Persona evaluation should happen again on save if/when the author changes.

    # $logger->debug('Stuffz: ', l4mtdump(
    #     {
    #     '$obj->id' => $obj->id,
    #     '$obj->author_id' => $obj->author_id,
    #     '$original->author_id' => $original->author_id,
    #     '$obj->is_changed(author_id)' => $obj->is_changed('author_id'),
    #     '$original->is_changed(author_id)' => $original->is_changed('author_id'),
    #     '$obj->class_type' => $obj->class_type,
    #     }
    # ));

}

sub persist_user_persona {
    my ( $app, $e, $user ) = @_;
    $logger        ||= MT::Log::Log4perl->new(); $logger->trace();
    my $epersona     = persona( $e );
    my $persona      = persona( $user || $e->author ) or return;
    if ( $persona ne $epersona ) {
        $app->param(entry_cust_field(), $persona);
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


sub cms_post_save_entry {
    my ($cb, $app, $obj, $orig) = @_;
    $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    # $logger->debug('$obj post save: ', l4mtdump($obj));
    # $logger->debug('$obj->meta_obj: ', l4mtdump($obj->meta_obj));
}

1;

__END__
