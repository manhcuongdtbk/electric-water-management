# Pure logic for the release demo bundler (rake demo:bundle, ADR-047/048).
# Collects the customer-facing demo clips that are NEW in a release (the delta
# vs the previous release tag) so the owner can review one set before forwarding
# it to the customer. Side-effecting orchestration (git, rspec, ffmpeg, file
# copy) lives in lib/tasks/demo.rake; this module holds the testable decisions.
module DemoBundle
  module_function

  # The infrastructure smoke recording is not a customer feature, so it never
  # belongs in a customer-facing bundle.
  SMOKE_SPEC = "spec/demo/smoke_demo_spec.rb"

  # Filter a list of changed repository paths down to the customer-facing demo
  # specs (ADR-047): keep spec/demo/*_spec.rb, drop the smoke spec. Sorted and
  # de-duplicated. Callers pass git-diff output already filtered to exclude
  # deletions (a removed spec has no feature to show).
  def select_specs(changed_paths)
    changed_paths
      .map(&:strip)
      .select { |path| path.start_with?("spec/demo/") && path.end_with?("_spec.rb") }
      .reject { |path| path == SMOKE_SPEC }
      .uniq
      .sort
  end

  # Parse the recorder sidecar (tmp/demo_videos/manifest.jsonl — one JSON object
  # per line) into clip entry hashes. Blank lines are ignored.
  def parse_manifest(jsonl)
    jsonl.each_line.filter_map do |line|
      line = line.strip
      next if line.empty?

      JSON.parse(line, symbolize_names: true)
    end
  end

  # Build the Vietnamese manifest.md body the owner reads when reviewing the
  # bundle. `clips` is the parsed sidecar entries; `missing` is the list of demo
  # spec paths that were rendered but produced no clip (surfaced loudly).
  def manifest_markdown(range:, clips:, missing:)
    lines = []
    lines << "# Bộ demo delta — chờ duyệt"
    lines << ""
    lines << "Khoảng release: `#{range}`"
    lines << ""
    lines << "> Owner duyệt nội dung từng clip TRƯỚC khi gửi khách (ADR-028/029)."
    lines << "> Clip dữ-liệu-sai / nửa-vời / nhạy cảm → sửa qua pipeline, KHÔNG gửi."
    lines << ""

    if clips.empty?
      lines << "_Không có clip nào trong bộ._"
    else
      lines << "| Clip | Tính năng (demo spec) | Anchor nghiệp vụ |"
      lines << "|---|---|---|"
      clips.each do |clip|
        spec_file = clip[:file].to_s.sub(%r{\A\./}, "")
        nv = clip[:nv].to_s.empty? ? "—" : clip[:nv]
        lines << "| `#{clip[:video]}` | #{clip[:description]} <br/>`#{spec_file}` | #{nv} |"
      end
    end

    if missing.any?
      lines << ""
      lines << "## ⚠️ Demo spec không sinh ra clip"
      lines << ""
      lines << "Các demo spec sau nằm trong delta nhưng KHÔNG render ra clip — kiểm tra lại:"
      lines << ""
      missing.sort.each { |path| lines << "- `#{path}`" }
    end

    lines << ""
    "#{lines.join("\n")}\n"
  end
end
