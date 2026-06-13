namespace :demo do
  desc "Load the curated demo dataset (db/seeds/demo.rb) into the current DB"
  task seed: :environment do
    load Rails.root.join("db", "seeds", "demo.rb")
  end

  desc "Transcode every tmp/demo_videos/*.webm to .mp4 (H.264) via ffmpeg"
  task transcode: :environment do
    dir = Rails.root.join("tmp", "demo_videos")
    failed = []
    Dir[dir.join("*.webm")].sort.each do |webm|
      mp4 = webm.sub(/\.webm\z/, ".mp4")
      ok = system("ffmpeg", "-y", "-loglevel", "error", "-i", webm,
                  "-c:v", "libx264", "-pix_fmt", "yuv420p", "-movflags", "+faststart", mp4)
      if ok
        puts "Transcoded #{File.basename(webm)} -> #{File.basename(mp4)}"
      else
        # Skip a single bad/partial recording (e.g. a Playwright temp artifact)
        # but keep transcoding the rest; fail the task at the end if any failed.
        failed << File.basename(webm)
        warn "Skipped (ffmpeg failed): #{File.basename(webm)}"
      end
    end
    abort("ffmpeg failed for: #{failed.join(', ')}") if failed.any?
  end

  desc "Bundle the customer-facing demo clips that are NEW in a release (delta " \
       "vs the previous release tag). Renders from the demo seed, packages the " \
       "clips + a Vietnamese manifest under tmp/demo_bundle/<label>/ for the " \
       "owner to review before forwarding to the customer (ADR-047/048). " \
       "Usage: rake 'demo:bundle[<since-ref>,<head-ref>]' (defaults: latest v* " \
       "tag .. HEAD). Sends nothing — the owner reviews and forwards."
  task :bundle, %i[since head] => :environment do |_task, args|
    video_dir = Rails.root.join("tmp", "demo_videos")
    git = ->(*cmd) { `git #{cmd.join(" ")}`.strip }

    since = args[:since].presence || git.call("describe", "--tags", "--abbrev=0", "--match", "'v*'")
    abort("demo:bundle: no <since> ref and no v* tag found — pass one explicitly.") if since.blank?
    head = args[:head].presence || "HEAD"

    # Delta of demo specs in the release range (ADR-047). --diff-filter=d drops
    # deletions (a removed spec has no feature to show).
    changed = git.call("diff", "--name-only", "--diff-filter=d", "#{since}..#{head}", "--", "spec/demo/").lines
    specs = DemoBundle.select_specs(changed)

    if specs.empty?
      puts "demo:bundle: no new customer-facing demo specs in #{since}..#{head} — nothing to bundle."
      next
    end

    puts "demo:bundle: #{specs.size} customer-facing demo spec(s) in #{since}..#{head}:"
    specs.each { |spec| puts "  - #{spec}" }

    # Render ONLY the delta from the demo seed (consistent, reproducible — ADR-041/048).
    # DEMO=1 lifts the type: :demo filter (spec/rails_helper.rb).
    FileUtils.rm_rf(video_dir)
    FileUtils.mkdir_p(video_dir)
    rendered = system({ "DEMO" => "1" }, "bundle", "exec", "rspec", *specs)
    abort("demo:bundle: rspec failed while rendering demo specs.") unless rendered

    Rake::Task["demo:transcode"].invoke

    # Authoritative clip→spec→NV mapping written by the recorder sidecar.
    manifest_jsonl = video_dir.join("manifest.jsonl")
    clips = manifest_jsonl.exist? ? DemoBundle.parse_manifest(File.read(manifest_jsonl)) : []
    # Keep only clips whose transcoded mp4 actually exists.
    clips = clips.select { |clip| video_dir.join(clip[:video].to_s).exist? }

    # Demo specs that rendered but produced no clip (e.g. all examples pending).
    produced_files = clips.map { |clip| clip[:file].to_s.sub(%r{\A\./}, "") }.uniq
    missing = specs - produced_files

    label = "#{since}_to_#{git.call('rev-parse', '--short', head)}".gsub(%r{[^\w.-]}, "_")
    bundle_dir = Rails.root.join("tmp", "demo_bundle", label)
    FileUtils.rm_rf(bundle_dir)
    FileUtils.mkdir_p(bundle_dir)

    clips.each { |clip| FileUtils.cp(video_dir.join(clip[:video]), bundle_dir.join(clip[:video])) }
    File.write(bundle_dir.join("manifest.md"),
               DemoBundle.manifest_markdown(range: "#{since}..#{head}", clips: clips, missing: missing))

    puts ""
    puts "demo:bundle: packaged #{clips.size} clip(s) → #{bundle_dir}"
    clips.each { |clip| puts "  + #{clip[:video]}" }
    if missing.any?
      warn ""
      warn "demo:bundle: WARNING — #{missing.size} demo spec(s) produced no clip (see manifest.md):"
      missing.sort.each { |path| warn "  ! #{path}" }
    end
    puts ""
    puts "Next: owner reviews #{bundle_dir.join('manifest.md')} + clips, then forwards to the customer (gate người)."
  end
end
