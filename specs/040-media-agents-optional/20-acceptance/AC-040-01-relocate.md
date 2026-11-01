# AC-040-01: Media agents absent from default child agent set

## AC-040-01-01 — Files relocated
Given the repository after the change
When `agents-optional/` and `agents/` are listed
Then `agents-optional/` contains media-image.md, media-video.md, media-voice.md, media-producer.md
And `agents/` contains no file matching `media-*.md`

## AC-040-01-02 — Default bridge links no media agent
Given a child repo set up by `templates/Makefile.bridge` without opt-in
When `.opencode/agents/` is listed
Then no file matching `media-*.md` is present

## AC-040-01-03 — No dangling references from default agents/commands
Given `agents/*.md` and `commands/*.md`
When grepped for `media-image|media-video|media-voice|media-producer`
Then there are no matches
