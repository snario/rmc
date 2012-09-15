define(
['ext/backbone', 'ext/jquery', 'ext/underscore', 'ext/underscore.string'],
function(Backbone, $, _, _s) {

  var CourseModel = Backbone.Model.extend({
    defaults: {
      'id': 'SCI 238',
      'name': 'Introduction to Astronomy omg omg omg',
      'rating': 2.5,
      'num_ratings': 49,
      'num_friends_took': 2,
      'description': 'This couse will introduce you to the wonderful world' +
        ' of astronomy. Learn about the Milky Way, the Big Bang, and' +
        ' everything in between. Become enthralled in the wonderful' +
        ' world of astronomy.'
    }
  });

  var CourseView = Backbone.View.extend({
    className: 'course well',

    initialize: function(options) {
      this.courseModel = options.courseModel;
    },

    render: function() {
      this.$el.html(
        _.template($('#course-tpl').html(), this.courseModel.toJSON()));

      return this;
    },

    events: {
      // TODO(david): Figure out a nicer interaction without requiring click
      'click .visible-section': 'toggleCourse',
      'focus .new-review-input': 'expandNewReview'
    },

    toggleCourse: function(evt) {
      if (this.$('.expand-section').is(':visible')) {
        this.collapseCourse(evt);
      } else {
        this.expandCourse(evt);
      }
    },

    expandCourse: function(evt) {
      var duration = 300;
      this.$('.expand-section')
        .css('opacity', 0)
        .animate({
          opacity: 1.0
        }, {
          duration: duration,
          queue: false
        })
        .slideDown(duration);
    },

    collapseCourse: function(evt) {
      this.$('.expand-section')
        .stop(/* clearQueue */ true)
        .slideUp(300);
    },

    expandNewReview: function(evt) {
      this.$('.new-review').addClass('new-review-expanded');
    }

  });


  var CourseCollection = Backbone.Collection.extend({
    model: CourseModel
  });


  // TODO(mack): make generic CollectionView
  var CourseCollectionView = Backbone.View.extend({
    tagName: 'ol',
    className: 'course-collection',

    initialize: function(options) {
      this.courseCollection = options.courseCollection;
      this.courseViews = [];
    },

    render: function() {
      this.$el.empty();
      this.courseCollection.each(function(courseModel) {
        var courseView = new CourseView({
          courseModel: courseModel,
          tagName: 'li'
        });
        this.$el.append(courseView.render().el);
        this.courseViews.push(courseView);
      }, this);

      return this;
    }
  });

  return {
    CourseModel: CourseModel,
    CourseView: CourseView,
    CourseCollection: CourseCollection,
    CourseCollectionView: CourseCollectionView
  };
});