#include <gtk/gtk.h>
#include <gtk4-layer-shell.h>

#include <signal.h>
#include <stdlib.h>
#include <string.h>

namespace {

constexpr int kSlideDistance = 430;
constexpr int kFinalRightMargin = 18;
constexpr int kTopMargin = 18;

struct NotificationState {
  GtkWidget* window = nullptr;
  int current_offset = kSlideDistance;
  int parent_pid = 0;
  guint animation_timer = 0;
};

const char* ArgValue(int argc, char** argv, const char* key) {
  for (int i = 1; i + 1 < argc; i++) {
    if (strcmp(argv[i], key) == 0) {
      return argv[i + 1];
    }
  }
  return "";
}

gboolean SlideIn(gpointer data) {
  auto* state = static_cast<NotificationState*>(data);
  state->current_offset -= 18;
  if (state->current_offset <= 0) {
    state->current_offset = 0;
    gtk_layer_set_margin(GTK_WINDOW(state->window), GTK_LAYER_SHELL_EDGE_RIGHT, kFinalRightMargin);
    state->animation_timer = 0;
    return G_SOURCE_REMOVE;
  }
  gtk_layer_set_margin(GTK_WINDOW(state->window), GTK_LAYER_SHELL_EDGE_RIGHT, kFinalRightMargin - state->current_offset);
  return G_SOURCE_CONTINUE;
}

gboolean SlideOut(gpointer data) {
  auto* state = static_cast<NotificationState*>(data);
  state->current_offset += 20;
  if (state->current_offset >= kSlideDistance) {
    gtk_window_destroy(GTK_WINDOW(state->window));
    return G_SOURCE_REMOVE;
  }
  gtk_layer_set_margin(GTK_WINDOW(state->window), GTK_LAYER_SHELL_EDGE_RIGHT, kFinalRightMargin - state->current_offset);
  return G_SOURCE_CONTINUE;
}

gboolean AutoHide(gpointer data) {
  auto* state = static_cast<NotificationState*>(data);
  if (state->animation_timer > 0) {
    g_source_remove(state->animation_timer);
  }
  state->animation_timer = g_timeout_add(16, SlideOut, state);
  return G_SOURCE_REMOVE;
}

void OnClicked(GtkGestureClick*, int, double, double, gpointer data) {
  auto* state = static_cast<NotificationState*>(data);
  if (state->parent_pid > 0) {
    kill(state->parent_pid, SIGUSR1);
  }
  gtk_window_destroy(GTK_WINDOW(state->window));
}

GtkWidget* CreateCover(const char* cover_path) {
  GtkWidget* frame = gtk_frame_new(nullptr);
  gtk_widget_add_css_class(frame, "cover-frame");
  gtk_widget_set_size_request(frame, 82, 82);

  GtkWidget* child = nullptr;
  if (cover_path && strlen(cover_path) > 0 && g_file_test(cover_path, G_FILE_TEST_EXISTS)) {
    child = gtk_picture_new_for_filename(cover_path);
    gtk_picture_set_content_fit(GTK_PICTURE(child), GTK_CONTENT_FIT_COVER);
  } else {
    child = gtk_label_new("♪");
    gtk_widget_add_css_class(child, "cover-fallback");
  }
  gtk_frame_set_child(GTK_FRAME(frame), child);
  return frame;
}

void LoadCss() {
  const char* css = R"CSS(
    window, window.background {
      background: transparent;
    }
    .notification {
      min-width: 386px;
      min-height: 116px;
      padding: 14px;
      border-radius: 24px;
      border: 1px solid rgba(167, 122, 29, 0.28);
      background: linear-gradient(135deg, rgba(255, 252, 243, 0.92), rgba(255, 246, 224, 0.78));
      box-shadow: 0 22px 52px rgba(42, 36, 22, 0.18);
    }
    .cover-frame {
      border-radius: 18px;
      border: 1px solid rgba(255, 255, 255, 0.45);
      overflow: hidden;
      background: rgba(255, 231, 163, 0.72);
    }
    .cover-frame picture {
      border-radius: 18px;
    }
    .cover-fallback {
      color: #2a2416;
      font-size: 34px;
      font-weight: 900;
    }
    .eyebrow {
      color: #eaa51f;
      font-size: 11px;
      font-weight: 900;
      letter-spacing: 0.08em;
    }
    .title {
      color: #2a2416;
      font-size: 16px;
      font-weight: 900;
    }
    .artist {
      color: #827354;
      font-size: 13px;
      font-weight: 700;
    }
  )CSS";

  GtkCssProvider* provider = gtk_css_provider_new();
  gtk_css_provider_load_from_string(provider, css);
  gtk_style_context_add_provider_for_display(gdk_display_get_default(), GTK_STYLE_PROVIDER(provider), GTK_STYLE_PROVIDER_PRIORITY_USER);
  g_object_unref(provider);
}

void Activate(GtkApplication* app, gpointer user_data) {
  char** argv = static_cast<char**>(user_data);
  int argc = 0;
  while (argv[argc] != nullptr) argc++;

  const char* title = ArgValue(argc, argv, "--title");
  const char* artist = ArgValue(argc, argv, "--artist");
  const char* cover = ArgValue(argc, argv, "--cover");
  const char* pid = ArgValue(argc, argv, "--pid");

  auto* state = new NotificationState();
  state->parent_pid = atoi(pid);

  LoadCss();

  GtkWidget* window = gtk_application_window_new(app);
  state->window = window;
  gtk_window_set_title(GTK_WINDOW(window), "Canary Now Playing");
  gtk_window_set_decorated(GTK_WINDOW(window), FALSE);
  gtk_window_set_resizable(GTK_WINDOW(window), FALSE);

  gtk_layer_init_for_window(GTK_WINDOW(window));
  gtk_layer_set_layer(GTK_WINDOW(window), GTK_LAYER_SHELL_LAYER_OVERLAY);
  gtk_layer_set_namespace(GTK_WINDOW(window), "canary-notification");
  gtk_layer_set_anchor(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_TOP, TRUE);
  gtk_layer_set_anchor(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
  gtk_layer_set_margin(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_TOP, kTopMargin);
  gtk_layer_set_margin(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_RIGHT, kFinalRightMargin - kSlideDistance);
  gtk_layer_set_keyboard_mode(GTK_WINDOW(window), GTK_LAYER_SHELL_KEYBOARD_MODE_NONE);

  GtkWidget* box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 14);
  gtk_widget_add_css_class(box, "notification");
  gtk_widget_set_valign(box, GTK_ALIGN_START);

  gtk_box_append(GTK_BOX(box), CreateCover(cover));

  GtkWidget* text_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
  gtk_widget_set_valign(text_box, GTK_ALIGN_CENTER);
  gtk_widget_set_hexpand(text_box, TRUE);

  GtkWidget* eyebrow = gtk_label_new("NOW PLAYING");
  gtk_widget_add_css_class(eyebrow, "eyebrow");
  gtk_label_set_xalign(GTK_LABEL(eyebrow), 0.0);

  GtkWidget* title_label = gtk_label_new(strlen(title) > 0 ? title : "Unknown Track");
  gtk_widget_add_css_class(title_label, "title");
  gtk_label_set_xalign(GTK_LABEL(title_label), 0.0);
  gtk_label_set_max_width_chars(GTK_LABEL(title_label), 31);
  gtk_label_set_ellipsize(GTK_LABEL(title_label), PANGO_ELLIPSIZE_END);

  gchar* artist_text = g_strdup_printf("By %s", strlen(artist) > 0 ? artist : "Unknown Artist");
  GtkWidget* artist_label = gtk_label_new(artist_text);
  g_free(artist_text);
  gtk_widget_add_css_class(artist_label, "artist");
  gtk_label_set_xalign(GTK_LABEL(artist_label), 0.0);
  gtk_label_set_max_width_chars(GTK_LABEL(artist_label), 31);
  gtk_label_set_ellipsize(GTK_LABEL(artist_label), PANGO_ELLIPSIZE_END);

  gtk_box_append(GTK_BOX(text_box), eyebrow);
  gtk_box_append(GTK_BOX(text_box), title_label);
  gtk_box_append(GTK_BOX(text_box), artist_label);
  gtk_box_append(GTK_BOX(box), text_box);

  GtkGesture* click = gtk_gesture_click_new();
  gtk_widget_add_controller(box, GTK_EVENT_CONTROLLER(click));
  g_signal_connect(click, "pressed", G_CALLBACK(OnClicked), state);

  gtk_window_set_child(GTK_WINDOW(window), box);
  gtk_window_present(GTK_WINDOW(window));

  state->animation_timer = g_timeout_add(16, SlideIn, state);
  g_timeout_add_seconds(4, AutoHide, state);
}

}  // namespace

int main(int argc, char** argv) {
  GtkApplication* app = gtk_application_new("com.canary.notification", G_APPLICATION_DEFAULT_FLAGS);
  g_signal_connect(app, "activate", G_CALLBACK(Activate), argv);
  int status = g_application_run(G_APPLICATION(app), 0, nullptr);
  g_object_unref(app);
  return status;
}
