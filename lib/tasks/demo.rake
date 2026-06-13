namespace :demo do
  desc "Load the curated demo dataset (db/seeds/demo.rb) into the current DB"
  task seed: :environment do
    load Rails.root.join("db", "seeds", "demo.rb")
  end

  desc "Transcode every tmp/demo_videos/*.webm to .mp4 (H.264) via ffmpeg"
  task transcode: :environment do
    dir = Rails.root.join("tmp", "demo_videos")
    Dir[dir.join("*.webm")].each do |webm|
      mp4 = webm.sub(/\.webm\z/, ".mp4")
      ok = system("ffmpeg", "-y", "-loglevel", "error", "-i", webm,
                  "-c:v", "libx264", "-pix_fmt", "yuv420p", "-movflags", "+faststart", mp4)
      abort("ffmpeg failed for #{webm}") unless ok
      puts "Transcoded #{File.basename(webm)} -> #{File.basename(mp4)}"
    end
  end
end
