class AddAnalysisWindowToVideos < ActiveRecord::Migration[8.0]
  def change
    add_column :videos, :analysis_start, :string
    add_column :videos, :analysis_end, :string
  end
end
